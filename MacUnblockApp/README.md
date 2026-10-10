# MacUnblock

一个 macOS 应用，通过拖拽、文件选择器或 Finder 右键菜单解除安装包的限制（移除 `com.apple.quarantine` 等隔离属性）。

支持所有常见的 macOS 安装包格式：`.app`、`.pkg`、`.mpkg`、`.dmg`、`.ipa`、`.appex`。

## 功能

- **拖拽解除限制**：打开应用后，将 `.app`、`.pkg`、`.dmg` 等文件直接拖到应用窗口的拖拽区域即可解除限制
- **点击选择文件**：点击窗口中的拖拽区域或「选择文件…」按钮，在弹出的文件选择器里挑选安装包（支持多选）
- **右键解除限制**：在 Finder 中右键任意安装包文件（`.app`、`.pkg`、`.dmg` 等），选择「解除安装限制」即可移除隔离属性
- **查看扩展属性**：在 Finder 右键菜单中查看文件当前的所有 xattr 扩展属性
- **自动清理**：递归移除 bundle 内所有文件的 `com.apple.quarantine`、`com.apple.provenance` 等限制属性
- **多选支持**：可同时拖入、多选或右键多个文件批量解除限制
- **双模式**：既能作为独立窗口应用使用（拖拽 / 选择文件），也能作为 Finder 扩展使用（右键模式）

## 支持的文件格式

| 格式 | 说明 |
|------|------|
| `.app` | macOS 应用程序（bundle） |
| `.pkg` | macOS 安装包 |
| `.mpkg` | 多包安装包 |
| `.dmg` | 磁盘映像文件 |
| `.ipa` | iOS 应用包 |
| `.appex` | 应用扩展（bundle） |

## 项目结构

```
MacUnblockApp/
├── MacUnblockApp/                    # 主应用
│   ├── AppDelegate.swift             # 主窗口、启用扩展引导界面
│   ├── NSViewExtension.swift         # NSView 辅助扩展
│   ├── Info.plist                    # 主应用 Info.plist
│   └── MacUnblock.entitlements       # 主应用权限文件
├── MacUnblockAppFinderSync/          # Finder Sync Extension
│   ├── SyncDelegate.swift            # 右键菜单逻辑
│   ├── Info.plist                    # Extension Info.plist
│   └── MacUnblockAppFinderSync.entitlements
├── MacUnblockApp.xcodeproj/          # Xcode 项目文件
├── Makefile                          # make install / run / status / uninstall
├── build.sh                          # 命令行构建脚本（Makefile 调用它）
└── README.md
```

## 构建方法

### 方式一：一条命令（推荐）

```bash
cd MacUnblockApp
make install
```

会自动完成：编译 → 签名 → 安装到 `/Applications/MacUnblock.app` → 向系统登记扩展，并提示后续步骤。

其他常用目标（`make help` 查看全部）：

| 命令 | 作用 |
|------|------|
| `make` / `make build` | 只构建，产物在 `build/MacUnblock.app` |
| `make install` | 构建 + 安装到 `/Applications` + 登记扩展 |
| `make run` | 安装后直接打开应用 |
| `make status` | 查看应用 / 扩展登记与运行状态 |
| `make restart-finder` | 让 Finder 重新加载扩展 |
| `make clean` | 清理 `build/` 产物 |
| `make uninstall` | 移到废纸篓并注销登记（可恢复） |

### 方式二：直接用脚本

```bash
cd MacUnblockApp
./build.sh
```

脚本会自动完成：编译 → 签名 → 安装到 `/Applications/MacUnblock.app` → 向系统登记扩展。

（只想构建不安装：`SKIP_INSTALL=1 ./build.sh`，产物在 `build/MacUnblock.app`。）

> 安装到 `/Applications` 是必要步骤：Finder 扩展只有在系统能发现应用时才会被登记。
> 另外同一个 bundle id 在 LaunchServices 中只能登记一份，脚本安装后会自动注销 `build/` 里的那份。

### 方式三：使用 Xcode（需先补两处配置）

Xcode 工程目前只适合调试扩展逻辑，直接用 `Cmd + B` 需要先补齐：

1. 把 `MacUnblockApp/main.swift` 加入 MacUnblock target 的 Compile Sources（工程文件里没有引用它，缺少入口会链接失败）
2. 在 Signing & Capabilities 中选择 “Sign to Run Locally”，或指定自己的开发者团队

日常构建/安装请用方式一，脚本已经处理好签名、安装与扩展登记。

## 使用方法

### 方式一：拖拽模式（无需配置 Finder 扩展）

1. 打开 `/Applications/MacUnblock.app`
2. 将 `.app`、`.pkg`、`.dmg` 等文件直接拖到应用窗口的拖拽区域
3. 应用会自动移除隔离属性并显示结果

### 方式二：点击选择文件（无需配置 Finder 扩展）

1. 打开 `/Applications/MacUnblock.app`
2. 点击窗口中的拖拽区域，或点「选择文件…」按钮（直接按回车也可以）
3. 在弹出的文件选择器里选中安装包（可按住 ⌘ / ⇧ 多选；`.app` 会以文件形式出现，直接选中即可）
4. 应用会自动移除隔离属性并显示结果

### 方式三：Finder 右键菜单

1. **构建并安装**：运行 `./build.sh`（会自动安装到 `/Applications`）
2. **启动应用**：打开 `MacUnblock.app`，会显示主窗口
3. **启用扩展**：点击「打开系统设置开启扩展」，在「系统设置 → 通用 → 登录项与扩展」中勾选 `MacUnblock`
4. **重启 Finder**：回到应用点「重启 Finder」（或终端执行 `killall Finder`），让 Finder 重新加载扩展
5. **使用**：在 Finder 中右键任意 `.app` / `.pkg` / `.dmg` 等文件 → 选择「🔓 解除安装限制」
   （右键菜单里能看到这一项，就说明扩展已经生效）

## 工作原理

当你在 macOS 上下载安装包时，系统会给文件添加 `com.apple.quarantine` 扩展属性，导致：
- `.app` 打开时提示「无法验证开发者」或「已损坏，无法打开」
- `.pkg` / `.mpkg` 安装时提示「无法打开，因为来自身份不明的开发者」
- `.dmg` 挂载时可能被阻止

本应用直接调用 libsystem 的 `listxattr` / `removexattr`，在当前进程内递归移除文件及 bundle 内所有文件的隔离属性。

### 移除的属性

| 属性 | 说明 |
|------|------|
| `com.apple.quarantine` | 隔离属性，标记从网络下载的文件 |
| `com.apple.provenance` | 来源属性（可能受 SIP 保护，移除失败不影响使用） |
| 其他扩展属性 | 递归移除，但保留 `com.apple.FinderInfo` / `com.apple.ResourceFork`（Finder 图标、标签等元数据） |

### 关键设计说明（重要）

1. **主应用不能使用 App Sandbox。**
   `/System/Library/Sandbox/Profiles/application.sb` 中硬编码了
   `(deny file-write-xattr (xattr "com.apple.quarantine"))`，
   任何沙箱进程都被系统禁止写入隔离属性，且无法通过 entitlements 绕过。
   因此主应用的 `MacUnblock.entitlements` 是空的，专门运行在沙箱之外。

2. **不调用 `/usr/bin/xattr` 子进程。**
   父进程从拖拽/选择文件获得的 sandbox extension 不会继承给 `Process` 启动的子进程，
   子进程访问该文件会直接 `EPERM`——这正是旧版本
   `xattr: [Errno 1] Operation not permitted` 报错的来源。改为进程内调用原生 API 后不再存在该问题。

3. **Finder 扩展只做转发。**
   Finder 扩展必须运行在沙箱中，所以它无法亲自移除隔离属性；
   它把选中的文件路径通过 `macunblock://` URL Scheme 交给主应用执行。
   出于安全考虑，主应用只处理用户主目录、`/Applications`、`/Volumes` 下的受支持格式文件。

4. **扩展状态的检测是"尽力而为"。**
   新版 macOS 收紧了 `pluginkit` 的查询权限（普通进程调用会返回
   `unauthorized discovery flag (PKDiscoverAll)`），因此应用无法百分之百判断扩展是否已启用。
   遇到这种情况会给出中性提示，并以"Finder 右键菜单能否看到「🔓 解除安装限制」"作为最终判据。

5. **`NSExtensionPrincipalClass` 必须写 Swift 模块全名。**
   Swift 类在 Objective-C 运行时里的名字带模块前缀（`MacUnblockAppFinderSync.SyncDelegate`），
   写成裸名 `SyncDelegate` 时扩展宿主用 `NSClassFromString` 查不到主类，
   扩展会静默加载失败——表现就是"系统设置里像开了，但 Finder 右键菜单什么都不出现"。
   因此 `build.sh` 的 `-module-name` 与 `Info.plist` 里的 `NSExtensionPrincipalClass` 必须保持一致。

6. **同一个 bundle id 只登记一份。**
   `LaunchServices` 里同时存在 `/Applications/MacUnblock.app` 和 `build/MacUnblock.app` 两份时，
   扩展解析会变得不确定，Finder 可能挑中构建目录那一份而拒绝加载。
   `build.sh` 在安装后会把 `build/` 里那份注销掉，只保留 `/Applications` 中的。

## 系统要求

- macOS 12.0+ (Monterey)
- Xcode 命令行工具（用于编译）

## 常见问题

**Q：提示「权限不足（Operation not permitted）」怎么办？**
文件位于「桌面 / 下载 / 文稿」等受保护目录时，首次访问系统会弹出授权提示，点击「允许」即可；
若之前拒绝过，请在「系统设置 → 隐私与安全性 → 完全磁盘访问权限」中勾选 MacUnblock 后重启应用。

**Q：重新构建后又要重新授权？**
因为使用 ad-hoc 签名，每次重新编译签名指纹都会变化，macOS 会把它当成新应用重新询问。
把应用固定放在 `/Applications` 并避免频繁重编译即可减少这种打扰。

**Q：右键菜单里没有「解除安装限制」？**
按顺序排查：

1. 在「系统设置 → 通用 → 登录项与扩展 → 文件提供程序 / Finder 扩展」中确认 `MacUnblock` 已勾选；
2. 回到 MacUnblock 主窗口点「重启 Finder」（或终端执行 `killall Finder`）——扩展被启用或重新构建后必须重新加载才生效；
3. 确认应用位于 `/Applications`（应用窗口底部的状态栏会提示当前运行位置）；
4. 以上都做过还是没有，重新执行 `./build.sh`（新版本修掉了扩展主类名与重复登记的问题，这两个都会导致菜单不出现）。

不想折腾扩展也没关系：**拖拽**和**点击「选择文件…」**这两种方式完全不依赖 Finder 扩展。

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

本应用只是将这个操作封装为 Finder 右键菜单，方便日常使用。
