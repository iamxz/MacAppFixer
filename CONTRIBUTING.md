# 贡献指南 / Contributing

感谢你对 MacUnblock 项目的关注！欢迎各种形式的贡献。
Thanks for your interest in MacUnblock — all kinds of contributions are welcome.

## 报告 Bug / Report a bug

请通过 [GitHub Issues](https://github.com/iamxz/MacUnblockApp/issues) 报告，并使用 Bug 报告模板，附上：
Please file it on [GitHub Issues](https://github.com/iamxz/MacUnblockApp/issues) using the bug template, including:

- 清晰的问题描述 / a clear description
- 复现步骤 / steps to reproduce
- 期望行为与实际行为 / expected vs. actual behavior
- 环境信息（macOS 版本、应用版本、系统语言）/ environment (macOS version, app version, system language)
- 截图（如适用）/ screenshots (if applicable)

## 提交功能建议 / Suggest a feature

欢迎通过 [GitHub Issues](https://github.com/iamxz/MacUnblockApp/issues) 使用功能建议模板提交。
Open an issue with the feature-request template.

## Pull Request

### 开发环境 / Setup

1. Fork 并克隆仓库 / Fork and clone
   ```bash
   git clone https://github.com/your-username/MacUnblockApp.git
   cd MacUnblockApp
   ```
2. 构建（产物在 `build/MacUnblock.app`）/ Build
   ```bash
   make build
   ```
3. 运行单元测试 / Run unit tests
   ```bash
   make test
   ```
4. 验证签名 / Verify signature
   ```bash
   codesign --verify --deep --strict build/MacUnblock.app
   ```

> 项目用 Swift Package Manager 组织（`Package.swift`）；逻辑层在 `Sources/MacUnblockCore/`，应用层在 `Sources/MacUnblock/`，新增源文件无需改动工程文件。
> `CI` 以「编译通过 + 单元测试通过 + 签名校验 + 通用二进制 + 本地化资源齐全」作为通过标准。
> The project uses Swift Package Manager (`Package.swift`); CI passes on “compiles + unit tests pass + signature verifies + universal binary + localizations present”.

### 提交规范 / Commit & PR conventions

- 使用清晰的提交信息 / use clear commit messages
- 每个 PR 聚焦一个功能或修复 / keep each PR focused on one thing
- 确保 `make build` 通过 / make sure `make build` passes

### 分支命名 / Branch names

- `feature/xxx` — 新功能 / new feature
- `fix/xxx` — Bug 修复 / bug fix
- `docs/xxx` — 文档更新 / documentation

### 代码规范 / Code style

- 遵循现有 Swift 风格 / follow the existing Swift style
- 添加必要的注释 / add necessary comments
- 保持代码可读性 / keep the code readable

### 本地化 / Localization

新增或修改任何面向用户的文案时，**必须同时**更新两个文件：
When adding or changing any user-facing string, you **must** update both files:

- `Resources/en.lproj/Localizable.strings`
- `Resources/zh-Hans.lproj/Localizable.strings`

文案通过 `L.t("key")` 取用（见 `Sources/MacUnblockCore/Localization.swift`）。带参数时用 `%@` / `%d` 占位符。
Strings are retrieved via `L.t("key")`; use `%@` / `%d` placeholders for parameters.

## 获取帮助 / Getting help

如有任何问题，请通过 GitHub Issues 联系我们。
Any questions? Reach us via GitHub Issues.
