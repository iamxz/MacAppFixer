[![CI](https://github.com/iamxz/MacUnblockApp/actions/workflows/ci.yml/badge.svg)](https://github.com/iamxz/MacUnblockApp/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/iamxz/MacUnblockApp)](https://github.com/iamxz/MacUnblockApp/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# MacUnblock

**简体中文** | [English](README.en.md)

<img src="screenshots/icon.png" width="112" alt="MacUnblock 应用图标">

一个 macOS 小工具：拖拽安装包、或点「选择文件…」挑一个，一键解除它的安装限制（移除 `com.apple.quarantine` 等隔离属性），让「已损坏 / 无法验证开发者」的提示消失。

支持所有常见的 macOS 安装包格式：`.app`、`.pkg`、`.mpkg`、`.dmg`、`.ipa`、`.appex`。

界面**中英双语**：跟随系统「语言与地区」设置自动切换，无需手动选择。

## 功能

- **拖拽解除限制**：把 `.app`、`.pkg`、`.dmg` 等文件直接拖到窗口的拖拽区域即可
- **点击选择文件**：点拖拽区域或「选择文件…」按钮，在弹出的文件选择器里挑选（支持多选）
- **批量处理**：一次拖入或选中多个文件，统一解除
- **自动清理**：递归移除 bundle 内所有文件的 `com.apple.quarantine`、`com.apple.provenance` 等限制属性
- **保留有用元数据**：不动 `com.apple.FinderInfo` / `com.apple.ResourceFork`，Finder 图标、标签等不受影响
- **中英双语**：随系统语言自动切换
- **纯本地、无网络**：不联网、不打开网页、不执行外部脚本

## 支持的文件格式

| 格式 | 说明 |
|------|------|
| `.app` | macOS 应用程序（bundle） |
| `.pkg` | macOS 安装包 |
| `.mpkg` | 多包安装包 |
| `.dmg` | 磁盘映像文件 |
| `.ipa` | iOS 应用包 |
| `.appex` | 应用扩展（bundle） |

## 系统要求

- macOS 12.0+ (Monterey)
- 构建需要 Xcode 命令行工具（`swift` / `xcrun`）

## 安装

### 方式一：下载安装包（推荐）

从 [GitHub Releases](https://github.com/iamxz/MacUnblockApp/releases) 下载最新的 `.pkg`，双击安装到 `/Applications/MacUnblock.app`；或下载 `.app.zip` 解压后拖入「应用程序」。

校验下载完整性：

```sh
shasum -a 256 -c checksums.txt
```

> app 为 **ad-hoc 签名**、安装包**未签名、未公证**，首次打开可能被 Gatekeeper 拦截，任选一种放行：
> - 右键 pkg →「打开」
> - 系统设置 →「隐私与安全性」→「仍要打开」

### 方式二：从源码构建

```bash
git clone https://github.com/iamxz/MacUnblockApp.git
cd MacUnblockApp
make install      # 编译 → 签名 → 安装到 /Applications/MacUnblock.app
```

## 构建

项目用 **Swift Package Manager** 组织（见 `Package.swift`）：`swift build` 产出可执行文件，再由 `make assemble` 把它组装成 `.app`（`Resources/` 里的 `Info.plist`、图标、`*.lproj`、`entitlements` 一并拷入并做 ad-hoc 签名）。

| 命令 | 作用 |
|------|------|
| `make` / `make build` | 编译 + 组装，产物在 `build/MacUnblock.app` |
| `make universal` | 通用架构（arm64 + x86_64）编译 + 组装 |
| `make test` | 运行单元测试 |
| `make install` | 组装 + 安装到 `/Applications` |
| `make run` | install 后直接打开应用 |
| `make status` | 查看安装与版本状态 |
| `make clean` | 清理 `.build/` 与 `build/` |
| `make uninstall` | 移到废纸篓并注销登记（可恢复） |
| `make pkg` | 通用架构编译 + 打成 `.pkg` |
| `make dist` | `pkg` + `.app.zip` + `checksums.txt`（发版用） |

也可以直接用 SPM：

```bash
swift build           # 只编译，产出 .build/release/MacUnblock
swift test            # 运行单元测试
make assemble         # 编译 + 组装成 build/MacUnblock.app
```

## 使用方法

1. 打开 `/Applications/MacUnblock.app`
2. 把 `.app` / `.pkg` / `.dmg` 等文件**拖到窗口的拖拽区域**；或**点击拖拽区域 / 点「选择文件…」**，在文件选择器里选中（可 ⌘ / ⇧ 多选）
3. 应用会自动移除隔离属性，并在底部显示结果

## 程序双语（i18n）

界面文案不写死语言，全部通过 `NSLocalizedString` 读取 `*.lproj/Localizable.strings`：

```
Sources/MacUnblockCore/
└── Localization.swift                  # L.t("key") 取文案的入口

Resources/
├── en.lproj/Localizable.strings        # English（开发语言 / 兜底）
└── zh-Hans.lproj/Localizable.strings   # 简体中文
```

构建时这些 `*.lproj` 会被拷进 `MacUnblock.app/Contents/Resources/`，运行时从主 bundle 读取。

`Info.plist` 用 `CFBundleLocalizations` 声明支持的语言、`CFBundleDevelopmentRegion` 指定兜底语言。macOS 会按用户在「系统设置 → 通用 → 语言与地区」里的偏好自动选择：简体中文系统显示中文，英文系统显示英文，其他语言回退到英文。

**新增或修改界面文案时**，请同时更新 `en.lproj` 与 `zh-Hans.lproj` 两个文件（PR 模板里有对应检查项）。

## 工作原理

当你在 macOS 上下载安装包时，系统会给文件添加 `com.apple.quarantine` 扩展属性，导致：

- `.app` 打开时提示「无法验证开发者」或「已损坏，无法打开」
- `.pkg` / `.mpkg` 安装时提示「无法打开，因为来自身份不明的开发者」
- `.dmg` 挂载时可能被阻止

本应用直接在当前进程内调用 libsystem 的 `listxattr` / `removexattr`，递归移除文件及 bundle 内所有文件的隔离属性。

### 移除的属性

| 属性 | 说明 |
|------|------|
| `com.apple.quarantine` | 隔离属性，标记从网络下载的文件 |
| `com.apple.provenance` | 来源属性（可能受 SIP 保护，移除失败不影响使用） |
| 其他扩展属性 | 递归移除，但保留 `com.apple.FinderInfo` / `com.apple.ResourceFork`（Finder 图标、标签等元数据） |

### 关键设计说明

1. **主应用不能使用 App Sandbox。**
   `/System/Library/Sandbox/Profiles/application.sb` 中硬编码了
   `(deny file-write-xattr (xattr "com.apple.quarantine"))`，
   任何沙箱进程都被系统禁止写入隔离属性，且无法通过 entitlements 绕过。
   因此 `MacUnblock.entitlements` 是空的，应用专门运行在沙箱之外。

2. **不调用 `/usr/bin/xattr` 子进程。**
   父进程从拖拽/选择文件获得的 sandbox extension 不会继承给 `Process` 启动的子进程，
   子进程访问该文件会直接 `EPERM`——这正是旧版本
   `xattr: [Errno 1] Operation not permitted` 报错的来源。改为进程内调用原生 API 后不再存在该问题。

## 常见问题

**Q：提示「权限不足（Operation not permitted）」怎么办？**
文件位于「桌面 / 下载 / 文稿」等受保护目录时，首次访问系统会弹出授权提示，点击「允许」即可；
若之前拒绝过，请在「系统设置 → 隐私与安全性 → 完全磁盘访问权限」中勾选 MacUnblock 后重启应用。

**Q：重新构建后又要重新授权？**
因为使用 ad-hoc 签名，每次重新编译签名指纹都会变化，macOS 会把它当成新应用重新询问。
把应用固定放在 `/Applications` 并避免频繁重编译即可减少这种打扰。

**Q：界面语言不对？**
应用跟随系统语言。到「系统设置 → 通用 → 语言与地区」调整首选语言后重启应用即可。

## 替代方案（无需安装应用）

如果你不想安装应用，也可以在终端手动执行：

```bash
# 解除 .app 应用限制
xattr -r -d com.apple.quarantine /path/to/YourApp.app

# 解除 .pkg 安装包限制
xattr -d com.apple.quarantine /path/to/Installer.pkg

# 解除 .dmg 磁盘映像限制
xattr -d com.apple.quarantine /path/to/DiskImage.dmg
```

本应用只是把这些操作封装成一个图形界面，方便日常使用。

## 项目结构

```
MacUnblockApp/
├── .github/                    # CI / Release workflow、Issue & PR 模板
├── Package.swift               # Swift Package Manager 清单
├── Sources/
│   ├── MacUnblockCore/         # 逻辑层（不依赖 AppKit，可单测）
│   │   ├── Xattr.swift         # xattr 读写与 errno 翻译
│   │   ├── Unblocker.swift     # 递归解除限制 + 支持格式判定
│   │   └── Localization.swift  # 本地化入口 L.t(...)
│   └── MacUnblock/             # 应用层
│       ├── main.swift          # 程序入口
│       ├── AppDelegate.swift   # 主窗口、拖拽编排、结果展示
│       └── DropAreaView.swift  # 拖拽区域视图
├── Resources/                  # 构建时拷进 .app 的资源
│   ├── Info.plist              # 应用信息（含 CFBundleLocalizations）
│   ├── MacUnblock.icns         # 应用图标
│   ├── MacUnblock.entitlements # 空（刻意不用沙箱）
│   ├── en.lproj/               # 英文文案
│   └── zh-Hans.lproj/          # 中文文案
├── Tests/MacUnblockCoreTests/  # 逻辑层单元测试
├── docs/release-notes/         # 每个版本的更新说明（Release 正文来源）
├── scripts/release.sh          # 发版脚本
├── Makefile                    # 构建 / 组装 / 安装 / 发版封装
├── CHANGELOG.md                # 更新日志
├── CONTRIBUTING.md             # 贡献指南
└── LICENSE                     # MIT
```

## 发版

发版说明写在 `docs/release-notes/vX.Y.Z.md`（会拼进 GitHub Release 正文），然后：

```sh
make release VERSION=<x.y.z|patch|minor|major> MSG="提交信息"
```

脚本会：编译校验 → 改 `Resources/Info.plist` 双版本号 → 提交 → 打 `vX.Y.Z` tag → 推送。推送 tag 后 GitHub Actions 自动构建 `.pkg` / `.app.zip` / `checksums.txt` 并发布 Release。详见 [AGENTS.md](AGENTS.md)。

## 参与贡献

欢迎贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md)。更新历史见 [CHANGELOG.md](CHANGELOG.md)。

## License

[MIT](LICENSE) © 2026 iamxz
