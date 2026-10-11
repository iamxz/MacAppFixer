# Agent Instructions

## 项目速览

MacAppFixer 是一个 macOS 小工具（AppKit），通过「拖拽」或「选择文件」两种方式递归移除安装包上的隔离属性（`com.apple.quarantine` 等）。

项目曾用名 **MacUnblock**，v1.0.0 之后全量改名为 MacAppFixer（含 bundle id `com.macappfixer.app`）；仓库里若再出现 `MacUnblock` 字样，属于需要清理的残留。

项目用 **Swift Package Manager** 组织（见 `Package.swift`），源码按「逻辑层 / 应用层」拆分：

- `Sources/MacAppFixerCore/` — 逻辑层：xattr 读写（`Xattr`）、递归解除（`Unblocker`）、本地化入口（`L`）。**不依赖 AppKit**，可被单元测试直接覆盖。
- `Sources/MacAppFixer/` — 应用层：AppKit 界面（`AppDelegate`、`DropAreaView`）与程序入口（`main.swift`），依赖逻辑层。
- `Resources/` — `Info.plist`、图标 `MacAppFixer.icns`、空 `MacAppFixer.entitlements`、`en.lproj` 与 `zh-Hans.lproj`。
- `Tests/MacAppFixerCoreTests/` — 逻辑层单元测试。
- `Makefile` — 构建 / 组装 `.app` / 签名 / 打包 / 发版封装。

## 每次修改代码后

必须重新构建并重启应用以验证改动：

```bash
# 1. 编译并组装（产物在 build/MacAppFixer.app）
make build

# 2. 先关闭正在运行的实例（如果有）
killall MacAppFixer 2>/dev/null || true

# 3. 重新启动
open build/MacAppFixer.app
```

不要只编译不重启。每次改动都要执行完整流程，确保改动生效。

## 构建与校验

- `make build` — 编译并组装 `.app`（本机架构，产物在 `build/MacAppFixer.app`）
- `make universal` — 通用架构（arm64 + x86_64）编译 + 组装
- `make test` — 运行逻辑层单元测试（`swift test`）
- `codesign --verify --deep --strict build/MacAppFixer.app` — 校验 ad-hoc 签名
- CI 的通过标准：编译通过 + 单元测试通过 + 签名校验 + 通用二进制 + 本地化资源齐全

> 构建原理：`swift build` 只产出可执行文件；`.app` 由 `make assemble` 组装——把 `Resources/` 里的 `Info.plist`、图标、`*.lproj`、`entitlements` 拷进 bundle 并做 ad-hoc 签名。**新增源文件无需改动任何工程文件**（SPM 自动收集 `Sources/<Target>/` 下所有 `.swift`）。

## 本地化（重要）

界面文案一律走 `L.t("key")`（见 `Sources/MacAppFixerCore/Localization.swift`），实际文案放在：

- `Resources/en.lproj/Localizable.strings`（英文 / 兜底）
- `Resources/zh-Hans.lproj/Localizable.strings`（简体中文）

**新增或修改任何面向用户的字符串时，两个文件都要改**，否则另一种语言会漏显。
带参数时用 `%@` / `%d` 占位符（`L.t("key", arg1, arg2)`）。

## 发布与打包（交给 GitHub CI）

- **打包发布必须由 GitHub Actions 完成，不要自己本地打包产物作为对外发布版本。**
- 发版用脚本一步完成：`make release VERSION=<x.y.z|patch|minor|major> [MSG="提交信息"] [NOTES="更新说明"]`（即 `scripts/release.sh`）。它会依次做：前置校验（main 分支、不落后远端、tag 不重复）→ 准备更新说明 → 编译校验 → 改 `Resources/Info.plist` 双版本号 → 校验与 tag 一致 → commit → `git tag vX.Y.Z` → push main + tag。
- 推送 tag 后，CI（`.github/workflows/release.yml`）会自动构建 `.pkg` / `.app.zip` / `checksums.txt` 并发布到 GitHub Release。

### 更新说明（GitHub Release 正文）

- 正文来自仓库内的 `docs/release-notes/vX.Y.Z.md`（每个版本一份，随发版提交进 main）；GitHub 自动生成说明已关闭。
- **发版前先把这份文件写好**：用面向用户的中文，顶部 `## 更新内容` + bullet，写「用户能感知到什么」，不要写构建/内部细节。脚本遇到已存在的文件不会覆盖。
- 忘了写也不会发版失败：脚本会按上一个 tag 到 HEAD 的提交记录起草一份并提示，但那是占位草稿，**必须改写后再发**。
- CI 拼正文时只读 `main` 上的 `docs/release-notes/`：先取本版本说明，再接共用的 `_footer.md`（安装步骤与 Gatekeeper 放行说明）和 `Full Changelog` 比较链接。
- 已发布版本的说明可事后在 main 上修正，然后用 workflow 的 `workflow_dispatch` 指定 tag 重新发布（会先删旧 Release 再重建），不必动 tag。

## 代码规范

- 遵循 Swift API Design Guidelines，保持现有写法
- **逻辑层 `MacAppFixerCore` 不得引入 AppKit**；凡是给应用层使用（即跨模块）的类型与成员，必须标 `public`
- 主应用**刻意不使用 App Sandbox**（沙箱内无法写 `com.apple.quarantine`），`Resources/MacAppFixer.entitlements` 保持为空
- 不要改用子进程调用 `/usr/bin/xattr`（sandbox extension 不会继承给子进程，会 `EPERM`），继续用进程内 `listxattr` / `removexattr`
