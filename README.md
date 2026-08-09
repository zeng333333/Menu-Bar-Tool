# shTool

macOS 菜单栏工具应用，快速执行预配置的 shell 命令。

## 功能特点

- **托盘运行**：应用隐藏窗口，仅在菜单栏显示图标，点击图标展开菜单
- **配置化菜单**：通过 `config.json` 文件配置菜单项，无需修改代码即可添加/删除命令
- **命令执行**：通过 `zsh -c` 执行任意 shell 命令，兼容管道、通配符、重定向等语法
- **资源目录为 CWD**：命令中可用 `$(pwd)` 引用 App Bundle 的 Resources 目录（Tool、AtlasSigner 等打包资源都在这里）
- **结果提示**：执行失败时弹窗显示退出码和错误输出

## 配置文件格式

```json
[
    {
        "menu_name": "菜单显示名称",
        "cmd": "执行的 shell 命令"
    }
]
```

> 命令通过 `/bin/zsh -c` 执行，`$(pwd)` 指向 App Bundle 的 Resources 目录。例如：
> - 打开 App 内工具：`open $(pwd)/Tool/SchoonerCompiler-new`
> - 直接执行脚本：`$(pwd)/Tool/start_Atlas2`
> - 复合命令：`rm /tmp/a.txt ; echo ok >> /tmp/a.txt ; open $(pwd)/Tool/RPC_/FixtureContro`

## 项目结构

```
shTool/
├── AppDelegate.swift      # 应用入口，托盘菜单逻辑
├── ViewController.swift  # 默认视图控制器
├── Assets.xcassets/      # 应用图标资源
├── Base.lproj/           # 界面布局文件
└── shTool.entitlements   # 应用权限配置
shToolUITests/
├── Tool/                 # 工具目录（脚本、RPC、MIX 等）
├── AtlasSigner/          # Atlas 签名工具
├── config.json           # 菜单配置文件
└── config_backup/        # 配置备份
```
