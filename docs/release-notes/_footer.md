---

## 安装 / Install

1. 下载本页 Assets 里的 `MacAppFixer-<版本>.pkg`，双击即可安装到 `/Applications/MacAppFixer.app`；或下载 `MacAppFixer-<版本>.app.zip`，解压后拖入「应用程序」。
   Download `MacAppFixer-<version>.pkg` from the Assets below and double-click to install into `/Applications/MacAppFixer.app`; or download `MacAppFixer-<version>.app.zip`, unzip and drag it into Applications.
2. 校验下载完整性 / Verify the download:
   ```sh
   shasum -a 256 -c checksums.txt
   ```

## 首次打开放行（Gatekeeper）

本应用为 **ad-hoc 签名**，安装包**未签名、未公证**，别人首次打开会被 Gatekeeper 拦截，任选一种放行：

- 右键 pkg →「打开」
- 系统设置 →「隐私与安全性」→「仍要打开」

The app is **ad-hoc signed**; the package is **unsigned and not notarized**, so the first launch may be blocked by Gatekeeper. Either right-click the pkg → “Open”, or use System Settings → “Privacy & Security” → “Open Anyway”.
