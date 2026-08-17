import Cocoa

/// 菜单配置模型。
///
/// `cmd` 与 `submenu` 二选一:`cmd` 为可执行命令,`submenu` 为子菜单项数组(支持递归嵌套)。
struct MenuItem: Codable {
    let menuName: String
    let cmd: String?
    let submenu: [MenuItem]?
}

/// macOS 菜单栏托盘应用代理。
///
/// 从 App Bundle 的 Resources 目录读取 `config.json`，为每个配置项生成菜单项，
/// 点击后通过 `zsh -c` 异步执行对应 shell 命令。
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var config: [MenuItem] = []

    /// 自定义入口点：手动创建 AppDelegate 实例并设为 delegate，确保 applicationDidFinishLaunching 被调用。
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 纯托盘模式：隐藏主窗口
        NSApp.windows.forEach { $0.close() }
        NSApp.setActivationPolicy(.accessory)

        loadConfig()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        // 设置托盘图标，三级兜底：Assets.car image set → Bundle 中的 Tool.icns 文件 → emoji 文字
        let iconImage =
            NSImage(named: "Tool")
            ?? (Bundle.main.url(forResource: "Tool", withExtension: "icns").flatMap { NSImage(contentsOf: $0) })
        if let icon = iconImage {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            button.image = icon
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyUpOrDown
        } else {
            button.title = "🔧"
        }

        statusItem.menu = createMenu()
        statusItem.isVisible = true
        button.isHidden = false
    }

    /// 拦截窗口创建，确保无主窗口弹出。
    func application(_ application: NSApplication, didCreateWindow window: NSWindow) {
        window.close()
    }

    // MARK: - 配置加载

    /// 从 App Bundle 加载 `config.json` 配置文件。
    ///
    /// 配置为 JSON 数组，每项需包含 `menu_name` 字段，`cmd` 与 `submenu` 至少提供一个。
    private func loadConfig() {
        guard let path = Bundle.main.path(forResource: "config", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        else {
            print("❌ config.json 加载失败")
            return
        }

        let decoder = JSONDecoder()
        // JSON 中为 snake_case 键（menu_name），自动映射到模型的 camelCase 属性（menuName）
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let json = try? decoder.decode([MenuItem].self, from: data) {
            config = json
            print("✅ 加载配置成功，共 \(config.count) 项")
        } else {
            print("❌ config.json 解析失败")
        }
    }

    // MARK: - 菜单构建

    /// 根据配置数组构建托盘菜单，末尾附加"退出"项。
    ///
    /// - Returns: 填充好的 `NSMenu`。
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        buildMenuItems(config, into: menu)

        if !config.isEmpty { menu.addItem(.separator()) }

        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    /// 递归构建菜单项：有 `submenu` 的生成子菜单，否则生成可点击的命令项。
    ///
    /// 命令通过 `representedObject` 携带，`runCommand` 直接取用，无需索引查找。
    ///
    /// - Parameters:
    ///   - items: 待构建的配置项数组。
    ///   - menu: 构建结果写入的目标菜单。
    private func buildMenuItems(_ items: [MenuItem], into menu: NSMenu) {
        for item in items {
            let menuItem = NSMenuItem(title: item.menuName, action: nil, keyEquivalent: "")

            if let submenu = item.submenu, !submenu.isEmpty {
                let sub = NSMenu()
                buildMenuItems(submenu, into: sub)
                menuItem.submenu = sub
            } else if let cmd = item.cmd, !cmd.isEmpty {
                menuItem.action = #selector(runCommand(_:))
                menuItem.target = self
                menuItem.representedObject = cmd
            }

            menu.addItem(menuItem)
        }
    }

    // MARK: - 命令执行

    /// 菜单项点击回调，通过 `zsh -c` 异步执行配置中的 shell 命令。
    ///
    /// 工作目录默认为 App Bundle 的 Resources，命令中可使用 `$(pwd)` 引用该目录，
    /// 兼容管道、通配符、重定向等 shell 语法。
    ///
    /// - Parameter sender: 触发的菜单项，命令通过 `representedObject` 携带。
    @objc private func runCommand(_ sender: NSMenuItem) {
        guard let cmd = sender.representedObject as? String, !cmd.isEmpty else {
            showAlert(title: "执行失败", message: "无效的命令配置或索引")
            return
        }

        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", cmd]
        process.currentDirectoryPath = Bundle.main.resourceURL?.path ?? NSHomeDirectory()

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try process.run()
            } catch {
                self?.showAlert(title: "启动失败", message: "无法执行命令：\(error.localizedDescription)")
                return
            }

            process.waitUntilExit()

            let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let exitCode = process.terminationStatus

            if exitCode == 0 {
                if !stdout.isEmpty { print("✅ \(cmd) -> \(stdout)") }
            } else {
                self?.showAlert(title: "执行失败", message: "退出码：\(exitCode)\n错误：\(stderr)")
            }
        }
    }

    /// 退出应用。
    @objc private func quitApp() {
        NSApplication.shared.terminate(self)
    }

    // MARK: - 工具方法

    /// 在主线程显示模态弹窗。
    ///
    /// - Parameters:
    ///   - title: 弹窗标题
    ///   - message: 弹窗正文
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}
