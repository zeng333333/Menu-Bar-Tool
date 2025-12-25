import Cocoa
import Foundation
import AppKit


@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var config: [[String: Any]] = [] // 存储配置数据

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("applicationDidFinishLaunching")
        
        // 紧急兜底：隐藏所有可能的主窗口
        NSApp.windows.forEach { $0.close() }
        NSApp.setActivationPolicy(.accessory)
        
        // 加载配置文件
        loadConfig()
        
        // 创建托盘项
        statusItem = NSStatusBar.system.statusItem(withLength: 16)
        
        // 配置托盘按钮和图标
        guard let button = statusItem.button else {
            print("❌ 托盘按钮创建失败")
            return
        }
        
        if let iconImage = NSImage(named: "Tool") {
            iconImage.size = NSSize(width: 16, height: 16)
            iconImage.isTemplate = false
            button.image = iconImage
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            print("✅ 加载自定义图标成功")
        } else {
            button.title = "🔧"
            print("❌ 加载自定义图标失败")
        }
        
        // 构建菜单（从配置文件加载）
        statusItem.menu = createMenu()
        
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
        statusItem.isVisible = true
        button.isHidden = false
        
        print("✅ 托盘初始化完成")
    }
    
    // 加载config.json配置
    private func loadConfig() {
        if let appBundle = Bundle.main.path(forResource: "config", ofType: "json") {
            let configURL = URL(fileURLWithPath: appBundle)
            print("✅ 配置文件路径: \(configURL)")
            
            // 后续读取配置文件的逻辑
            do {
                let data = try Data(contentsOf: configURL)
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    config = jsonArray
                    print("✅ 加载配置成功，共\(config.count)项")
                }
            } catch {
                print("❌ 读取配置文件失败: \(error.localizedDescription)")
            }
        } else {
            print("❌ 配置文件不存在: Resources目录中未找到config.json")
        }
    }
    
    // 创建菜单（包含配置文件中的项）
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // 添加配置文件中的菜单项
        for (index, itemConfig) in config.enumerated() {
            guard let menuName = itemConfig["menu_name"] as? String,
                  let cmd = itemConfig["cmd"] as? String else {
                continue // 跳过无效配置
            }
            
            let menuItem = NSMenuItem(
                title: menuName,
                action: #selector(runCommand(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.tag = index // 用tag存储配置索引
            menu.addItem(menuItem)
        }
        
        // 添加分隔线和退出项
        if !config.isEmpty {
            menu.addItem(NSMenuItem.separator())
        }
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }

    
    // 核心执行函数参考python的subprocess.run
    @objc private func runCommand(_ sender: NSMenuItem) {
        let index = sender.tag
        // 1. 基础参数校验
        guard index < config.count,
              let itemConfig = config[index] as? [String: Any],
              let rawCmd = itemConfig["cmd"] as? String, !rawCmd.isEmpty
        else {
            print("❌ 无效命令/索引：索引越界或命令为空")
            showAlert(title: "执行失败", message: "无效的命令配置或索引")
            return
        }
        
        print("📝 执行命令: \(rawCmd)")
        
        // 2. 解析命令配置（对标 subprocess.run 的参数）
        // - cwd: 工作目录（可选）
        let cwd = itemConfig["cwd"] as? String
        // - env: 环境变量（可选，默认继承当前进程）
        let customEnv = itemConfig["env"] as? [String: String]
        // - timeout: 超时时间（秒，可选，默认无超时）
        let timeout = itemConfig["timeout"] as? TimeInterval
        // - shell: 是否通过 shell 执行（默认 true，兼容复杂命令如管道、通配符）
        let useShell = itemConfig["shell"] as? Bool ?? true
        // - captureOutput: 是否捕获输出（默认 true）
        let captureOutput = itemConfig["captureOutput"] as? Bool ?? true
        
        // 3. 拆分命令（如果不通过 shell 执行，需要拆分为 [命令, 参数] 数组）
        let (launchPath, arguments) = resolveCommand(rawCmd, useShell: useShell)
        
        // 4. 配置进程
        let process = Process()
        process.launchPath = launchPath
        if !arguments.isEmpty {
            process.arguments = arguments
        }
        var targetWorkDir: String?
        
        // 1. 优先使用外部传入的 cwd（保持原有逻辑）
        if let cwd = cwd, FileManager.default.fileExists(atPath: cwd) {
            targetWorkDir = cwd
            print("📂 使用自定义工作目录：\(cwd)")
        }
        // 2. 未传入 cwd 或 cwd 不存在时，使用 App 资源目录
        else if let resourceURL = Bundle.main.resourceURL {
            targetWorkDir = resourceURL.path
            print("📂 未指定自定义目录，使用 App 资源目录：\(targetWorkDir!)")
        }
        
        // 3. 最终设置工作目录（兜底：如果资源目录也获取失败，用默认用户目录）
        if let targetWorkDir = targetWorkDir {
            process.currentDirectoryPath = targetWorkDir
        } else {
            print("⚠️ 资源目录获取失败，使用默认工作目录：\(NSHomeDirectory())")
        }
        
        // 设置环境变量
        if let customEnv = customEnv, !customEnv.isEmpty {
            // 合并默认环境变量 + 自定义环境变量
            var env = ProcessInfo.processInfo.environment
            customEnv.forEach { env[$0.key] = $0.value }
            process.environment = env
        }
        
        // 5. 配置输出捕获（对标 subprocess.PIPE）
        let pipe = Pipe()
        let errorPipe = Pipe()
        if captureOutput {
            process.standardOutput = pipe
            process.standardError = errorPipe
        }
        
        // 6. 异步执行命令（避免阻塞主线程）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // 启动进程
                try process.run()
                
                // 超时控制（对标 subprocess.run(timeout=...)）
                if let timeout = timeout {
                    let timeoutSemaphore = DispatchSemaphore(value: 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                        if process.isRunning {
                            process.terminate() // 超时终止进程
                            timeoutSemaphore.signal()
                            print("⏰ 命令执行超时，已终止")
                            self?.showAlert(title: "执行超时", message: "命令执行超过 \(timeout) 秒，已终止")
                        }
                    }
                    
                    // 等待进程结束或超时
                    process.waitUntilExit()
                    timeoutSemaphore.wait()
                } else {
                    // 无超时，等待进程结束
                    process.waitUntilExit()
                }
                
                // 7. 读取输出（stdout/stderr）
                let stdoutData = pipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let stdout = String(data: stdoutData, encoding: .utf8) ?? "无标准输出"
                let stderr = String(data: stderrData, encoding: .utf8) ?? "无错误输出"
                
                // 8. 处理执行结果
                let exitCode = process.terminationStatus
                if exitCode == 0 {
                    print("✅ 命令执行成功")
                    print("📤 标准输出：\(stdout)")
                    if !stderr.isEmpty {
                        print("⚠️ 错误输出：\(stderr)")
                    }
                    //self?.showAlert(title: "执行成功", message: "输出：\(stdout)")
                } else {
                    print("❌ 命令执行失败，退出码：\(exitCode)")
                    print("📤 标准输出：\(stdout)")
                    print("📛 错误输出：\(stderr)")
                    self?.showAlert(title: "执行失败", message: "退出码：\(exitCode)\n错误信息：\(stderr)")
                }
                
            } catch {
                // 进程启动失败（如命令不存在）
                print("🚨 进程启动失败：\(error.localizedDescription)")
                self?.showAlert(title: "启动失败", message: "无法执行命令：\(error.localizedDescription)")
            }
        }
    }
    
    // 退出应用
    @objc private func quitApp() {
        print("applicationWillTerminate")
        NSApplication.shared.terminate(self)
    }
    
    // 拦截窗口创建
    func application(_ application: NSApplication, didCreateWindow window: NSWindow) {
        window.close()
    }

    /// 解析命令：区分是否通过 shell 执行
    /// - Parameters:
    ///   - rawCmd: 原始命令字符串
    ///   - useShell: 是否通过 shell 执行
    /// - Returns: (launchPath, arguments)
    private func resolveCommand(_ rawCmd: String, useShell: Bool) -> (String, [String]) {
        if useShell {
            // 通过 shell 执行（兼容管道、通配符、环境变量等）
            // macOS 默认 shell 是 /bin/zsh（也可指定 /bin/bash）
            let shellPath = "/bin/zsh"
            return (shellPath, ["-c", rawCmd])
        } else {
            // 直接执行命令（需拆分命令和参数，如 "ls -l" → ["ls", "-l"]）
            let components = rawCmd.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let launchPath = components.first else {
                return ("", [])
            }
            let arguments = Array(components.dropFirst())
            return (launchPath, arguments)
        }
    }
    
    /// 显示弹窗提示（主线程执行）
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
