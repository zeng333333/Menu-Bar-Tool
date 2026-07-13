# shTool

macOS 菜单栏工具应用，快速执行预配置的 shell 命令。

## 功能特点

- **托盘运行**：应用隐藏窗口，仅在菜单栏显示图标，点击图标展开菜单
- **配置化菜单**：通过 `config.json` 文件配置菜单项，无需修改代码即可添加/删除命令
- **命令执行**：支持执行任意 shell 命令，兼容管道、通配符等复杂命令
- **超时控制**：可配置命令执行超时时间
- **环境变量**：支持自定义环境变量
- **工作目录**：可指定命令执行的工作目录
- **结果提示**：执行完成后显示成功/失败提示

## 配置文件格式

```json
[
    {
        "menu_name": "菜单显示名称",
        "cmd": "执行的命令",
        "cwd": "工作目录（可选）",
        "env": { "KEY": "VALUE" },
        "timeout": 30,
        "shell": true,
        "captureOutput": true
    }
]
```

## 项目结构

```
shTool/
├── AppDelegate.swift      # 应用入口，托盘菜单逻辑
├── ViewController.swift  # 默认视图控制器
├── Assets.xcassets/      # 应用图标资源
├── Base.lproj/           # 界面布局文件
└── shTool.entitlements   # 应用权限配置
shToolUITests/
├── config.json           # 菜单配置文件
└── Tool_file/            # 测试脚本文件
```
