import Cocoa

/// macOS 菜单栏托盘应用代理。
///
/// 从 App Bundle 的 Resources 目录读取 `config.json`，为每个配置项生成菜单项，
/// 点击后异步执行对应 shell 命令（对标 Python `subprocess.run`）。
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
    /// 配置为 JSON 数组，每项含 `menu_name`、`cmd` 等字段。
    /// 加载失败时打印错误日志，`config` 保持空数组。
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
                  let cmd = item["cmd"] as? String else { continue }

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

    /// 菜单项点击回调，异步执行配置中的 shell 命令。
    ///
    /// 对标 Python `subprocess.run`，支持以下可选字段：
    /// - `cwd`：工作目录，不存在时回退到 App 资源目录
    /// - `env`：自定义环境变量（与系统环境合并）
    /// - `timeout`：超时秒数，超时后终止进程
    /// - `shell`：是否通过 `zsh -c` 执行（默认 true，兼容管道、通配符）
    /// - `captureOutput`：是否捕获 stdout/stderr（默认 true）
    ///
    /// - Parameter sender: 触发的菜单项，`tag` 对应配置数组索引。
    ///
    /// - Warning: 进程在后台线程执行，UI 弹窗通过 `showAlert` 回主线程显示。
    @objc private func runCommand(_ sender: NSMenuItem) {
        let index = sender.tag

        guard index < config.count,
              let item = config[index] as? [String: Any],
              let cmd = item["cmd"] as? String, !cmd.isEmpty
        else {
            showAlert(title: "执行失败", message: "无效的命令配置或索引")
            return
        }

        let cwd = item["cwd"] as? String
        let customEnv = item["env"] as? [String: String]
        let timeout = item["timeout"] as? TimeInterval
        let useShell = item["shell"] as? Bool ?? true
        let captureOutput = item["captureOutput"] as? Bool ?? true

        let (launchPath, arguments) = resolveCommand(cmd, useShell: useShell)

        let process = Process()
        process.launchPath = launchPath
        if !arguments.isEmpty { process.arguments = arguments }
        process.currentDirectoryPath = resolveWorkDir(cwd)

        if let customEnv = customEnv, !customEnv.isEmpty {
            var env = ProcessInfo.processInfo.environment
            customEnv.forEach { env[$0] = $1 }
            process.environment = env
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        if captureOutput {
            process.standardOutput = outPipe
            process.standardError = errPipe
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try process.run()
            } catch {
                self?.showAlert(title: "启动失败", message: "无法执行命令：\(error.localizedDescription)")
                return
            }

            // 超时定时器：到期时终止仍在运行的进程
            if let timeout = timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning {
                        process.terminate()
                        self?.showAlert(title: "执行超时", message: "命令执行超过 \(timeout) 秒，已终止")
                    }
                }
            }

            process.waitUntilExit()

            guard captureOutput else { return }

            let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let exitCode = process.terminationStatus

            if exitCode == 0 {
                print("✅ \(cmd) -> \(stdout)")
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

    /// 解析命令，区分 shell 执行与直接执行。
    ///
    /// - Parameters:
    ///   - rawCmd: 原始命令字符串
    ///   - useShell: `true` 时通过 `/bin/zsh -c` 执行（兼容管道、通配符）；`false` 时按空白拆分
    /// - Returns: `(launchPath, arguments)` 元组
    private func resolveCommand(_ rawCmd: String, useShell: Bool) -> (String, [String]) {
        if useShell {
            return ("/bin/zsh", ["-c", rawCmd])
        }
        let parts = rawCmd.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return (parts.first ?? "", Array(parts.dropFirst()))
    }

    /// 解析工作目录，优先级：配置 cwd > App 资源目录 > 用户主目录。
    ///
    /// - Parameter cwd: 配置中的工作目录路径，可为 nil 或不存在
    /// - Returns: 实际使用的工作目录绝对路径
    private func resolveWorkDir(_ cwd: String?) -> String {
        if let cwd = cwd, FileManager.default.fileExists(atPath: cwd) {
            return cwd
        }
        return Bundle.main.resourceURL?.path ?? NSHomeDirectory()
    }

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
