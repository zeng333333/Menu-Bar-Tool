import Cocoa

/// macOS 菜单栏托盘应用代理。
///
/// 从 App Bundle 的 Resources 目录读取 `config.json`，为每个配置项生成菜单项，
/// 点击后通过 `zsh -c` 异步执行对应 shell 命令。
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var config: [[String: Any]] = []

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 纯托盘模式：隐藏主窗口
        NSApp.windows.forEach { $0.close() }
        NSApp.setActivationPolicy(.accessory)

        loadConfig()

        statusItem = NSStatusBar.system.statusItem(withLength: 16)
        guard let button = statusItem.button else { return }

        // 设置托盘图标，加载失败降级为 emoji
        if let icon = NSImage(named: "Tool") {
            icon.size = NSSize(width: 16, height: 16)
            icon.isTemplate = false
            button.image = icon
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
        } else {
            button.title = "🔧"
        }

        statusItem.menu = createMenu()
        NSApp.activate(ignoringOtherApps: true)
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
    /// 配置为 JSON 数组，每项需包含 `menu_name` 和 `cmd` 字段。
    private func loadConfig() {
        guard let path = Bundle.main.path(forResource: "config", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            print("❌ config.json 加载失败")
            return
        }
        config = json
        print("✅ 加载配置成功，共 \(config.count) 项")
    }

    // MARK: - 菜单构建

    /// 根据配置数组构建托盘菜单，末尾附加"退出"项。
    ///
    /// - Returns: 填充好的 `NSMenu`，每个菜单项的 `tag` 存储配置索引。
    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        for (index, item) in config.enumerated() {
            guard let name = item["menu_name"] as? String,
                  (item["cmd"] as? String) != nil else { continue }

            let menuItem = NSMenuItem(title: name, action: #selector(runCommand(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = index
            menu.addItem(menuItem)
        }

        if !config.isEmpty { menu.addItem(.separator()) }

        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    // MARK: - 命令执行

    /// 菜单项点击回调，通过 `zsh -c` 异步执行配置中的 shell 命令。
    ///
    /// 工作目录默认为 App Bundle 的 Resources，命令中可使用 `$(pwd)` 引用该目录，
    /// 兼容管道、通配符、重定向等 shell 语法。
    ///
    /// - Parameter sender: 触发的菜单项，`tag` 对应配置数组索引。
    @objc private func runCommand(_ sender: NSMenuItem) {
        let index = sender.tag

        guard index < config.count,
              let item = config[index] as? [String: Any],
              let cmd = item["cmd"] as? String, !cmd.isEmpty
        else {
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
