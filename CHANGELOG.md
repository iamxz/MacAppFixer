# Changelog

本项目所有值得记录的变更都会写在这里。
格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### 中文

**变更**
- 项目更名为 **MacAppFixer**（曾用名 MacUnblock）：App 名、bundle id（`com.macappfixer.app`）、模块名、构建产物与仓库地址同步更新
- 更名不影响功能：bundle id 变了，新版本不会覆盖旧安装，需手动删除 `/Applications/MacUnblock.app`

### English

**Changed**
- Renamed to **MacAppFixer** (formerly MacUnblock): app name, bundle id (`com.macappfixer.app`), module names, build artifacts and repository URL
- Functionality is unchanged: the bundle id changed, so the new build won't replace an old install — delete `/Applications/MacUnblock.app` manually

## [1.0.0] - 2026-10-10

### 中文

**新增**
- 拖拽解除限制：把 `.app` / `.pkg` / `.mpkg` / `.dmg` / `.ipa` / `.appex` 拖到窗口即可
- 点击「选择文件…」挑选安装包，支持多选与批量处理
- 进程内调用 `listxattr` / `removexattr` 递归移除隔离属性，无需子进程、无 `EPERM` 问题
- 移除 `com.apple.quarantine`、`com.apple.provenance` 等属性，保留 `com.apple.FinderInfo` / `com.apple.ResourceFork`
- **中英双语界面**：通过 `NSLocalizedString` + `*.lproj` 随系统语言自动切换
- `make pkg` 产出 Universal（arm64 + x86_64）安装包
- GitHub Actions：CI 编译校验 + tag 自动打包发布

### English

**Added**
- Drag & drop to unblock `.app` / `.pkg` / `.mpkg` / `.dmg` / `.ipa` / `.appex`
- “Choose File…” picker with multi-select and batch handling
- In-process `listxattr` / `removexattr` recursion — no subprocess, no `EPERM`
- Strips `com.apple.quarantine`, `com.apple.provenance`, … while keeping `com.apple.FinderInfo` / `com.apple.ResourceFork`
- **Bilingual UI (English / Simplified Chinese)** via `NSLocalizedString` + `*.lproj`, following the system language
- `make pkg` produces a Universal (arm64 + x86_64) installer
- GitHub Actions: CI build checks + tag-triggered packaging and release

[Unreleased]: https://github.com/iamxz/MacAppFixer/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/iamxz/MacAppFixer/releases/tag/v1.0.0
