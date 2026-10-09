# MacUnblock

一个 macOS 应用，通过 Finder 右键菜单解除应用的安装限制（移除 `com.apple.quarantine` 等隔离属性）。

## 功能

- **右键解除限制**：在 Finder 中右键任意 `.app` 文件，选择「解除安装限制」即可移除隔离属性
- **查看扩展属性**：查看 `.app` 文件当前的所有 xattr 扩展属性
- **自动清理**：递归移除 `.app` bundle 内所有文件的 `com.apple.quarantine`、`com.apple.provenance` 等限制属性

## 项目结构

```
MacUnblockApp/
├── MacUnblockApp/                    # 主应用
│   ├── AppDelegate.swift             # 主窗口、启用扩展引导界面
│   ├── NSViewExtension.swift         # NSView 辅助扩展
│   ├── Info.plist                    # 主应用 Info.plist
│   └── MacUnblock.entitlements       # 主应用权限文件
├── MacUnblockAppFinderSync/          # Finder Sync Extension
│   ├── FinderSync.swift              # 右键菜单逻辑
│   ├── Info.plist                    # Extension Info.plist
│   └── MacUnblockAppFinderSync.entitlements
├── MacUnblockApp.xcodeproj/          # Xcode 项目文件
├── build.sh                          # 命令行构建脚本
└── README.md
```

## 构建方法

### 方式一：使用 Xcode（推荐）

1. 用 Xcode 打开 `MacUnblockApp/MacUnblockApp.xcodeproj`
2. `Cmd + B` 构建
3. `Cmd + R` 运行

### 方式二：使用命令行脚本

```bash
cd MacUnblockApp
./build.sh
```

构建完成后，应用会在 `build/MacUnblock.app`。

## 使用方法

1. **启动应用**：打开 `MacUnblock.app`，会显示主窗口引导界面
2. **启用扩展**：点击「启用 Finder 扩展」按钮，系统会自动注册扩展并打开系统设置
3. **允许扩展**：在系统设置 → 隐私与安全性 → 扩展 → 添加的扩展中，勾选 `MacUnblock`
4. **使用**：在 Finder 中右键任意 `.app` 文件 → 选择「🔓 解除安装限制」

## 工作原理

当你在 macOS 上下载安装第三方应用时，系统会给文件添加 `com.apple.quarantine` 扩展属性，导致应用打开时提示「无法验证开发者」或「已损坏，无法打开」。

本应用通过调用 `xattr -r -d com.apple.quarantine` 命令，递归移除 `.app` bundle 内所有文件的隔离属性，从而解除安装限制。

### 移除的属性

| 属性 | 说明 |
|------|------|
| `com.apple.quarantine` | 隔离属性，标记从网络下载的文件 |
| `com.apple.provenance` | 来源属性（可能受 SIP 保护，移除失败不影响使用） |
| 其他所有 xattr | 递归移除所有扩展属性 |

## 系统要求

- macOS 12.0+ (Monterey)
- Xcode 14+（如使用 Xcode 构建）

## 技术说明

- 主应用使用 `NSWindow` 创建引导界面，检测扩展安装状态
- Finder Sync Extension (`FIFinderSync`) 提供右键菜单功能
- 通过 `Process` 调用 `/usr/bin/xattr` 命令操作文件属性
- 扩展未启用沙箱（`app-sandbox: false`），因为需要执行 `xattr` 命令

## 替代方案（无需安装应用）

如果你不想安装应用，也可以在终端手动执行：

```bash
xattr -r -d com.apple.quarantine /path/to/YourApp.app
```

本应用只是将这个操作封装为 Finder 右键菜单，方便日常使用。
