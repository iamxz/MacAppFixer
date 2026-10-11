[![CI](https://github.com/iamxz/MacAppFixer/actions/workflows/ci.yml/badge.svg)](https://github.com/iamxz/MacAppFixer/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/iamxz/MacAppFixer)](https://github.com/iamxz/MacAppFixer/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# MacAppFixer

**English** | [简体中文](README.zh-CN.md)

<img src="screenshots/icon.png" width="112" alt="MacAppFixer app icon">

**Fixes Mac apps that refuse to install: "is damaged and can't be opened", "cannot be launched because it is from an unidentified developer".**

A tiny macOS utility: drop an installer onto the window — or pick one with "Choose File…" — and it strips the quarantine attributes (`com.apple.quarantine`, etc.) in one click, so the warning goes away.

Supports `.app`, `.pkg`, `.mpkg`, `.dmg`, `.ipa`, `.appex`. The UI is bilingual (English / 简体中文) and follows your macOS language automatically.

## Screenshots

<p align="center">
  <img src="screenshots/screenshot-en.jpg" width="360" alt="MacAppFixer main window (English)">
  &nbsp;&nbsp;
  <img src="screenshots/screenshot-zh.jpg" width="360" alt="MacAppFixer main window (Simplified Chinese)">
</p>

## Features

- **Drag & drop** or **Choose File…** (multi-select, batch)
- **Recursive cleanup** of `com.apple.quarantine` / `com.apple.provenance` inside bundles
- **Preserves** `com.apple.FinderInfo` / `com.apple.ResourceFork` (icons, tags stay intact)
- **Bilingual UI**, auto-switches with system language
- **Fully local, no network**

## Requirements

- macOS 12.0+ (Monterey)
- Xcode Command Line Tools (`swift` / `xcrun`) to build

## Install

### Download (recommended)

Get the latest `.pkg` from [GitHub Releases](https://github.com/iamxz/MacAppFixer/releases) and double-click to install to `/Applications/MacAppFixer.app`; or grab `.app.zip`, unzip and drag into Applications.

> Ad-hoc signed, not notarized. If Gatekeeper blocks it: right-click → "Open", or System Settings → Privacy & Security → "Open Anyway".

> Renamed from **MacUnblock** (old bundle id `com.macunblock.app`). Since the bundle id changed, the new app won't overwrite an old install — delete `/Applications/MacUnblock.app` first.

### Build from source

```bash
git clone https://github.com/iamxz/MacAppFixer.git
cd MacAppFixer
make install      # build → sign → install to /Applications/MacAppFixer.app
```

## Usage

1. Open `/Applications/MacAppFixer.app`
2. Drag a file onto the drop area, or click it / "Choose File…" (⌘ / ⇧ to multi-select)
3. Attributes are removed; the result shows at the bottom

## FAQ

**Permission denied?** Files in Desktop / Downloads / Documents prompt for Full Disk Access on first use — click "Allow". If you previously denied it, enable MacAppFixer under System Settings → Privacy & Security → Full Disk Access, then relaunch.

**Re-asked to authorize after a rebuild?** The app is ad-hoc signed, so each rebuild changes its identity. Keep it in `/Applications` and rebuild less often to cut the prompts.

**Wrong UI language?** The app follows the system language. Change it in System Settings → General → Language & Region and relaunch.

## Without the app (Terminal)

```bash
xattr -r -d com.apple.quarantine /path/to/YourApp.app
xattr -d  com.apple.quarantine /path/to/Installer.pkg
xattr -d  com.apple.quarantine /path/to/DiskImage.dmg
```

This app is just a GUI wrapper around the above.

## Development

Built with Swift Package Manager. Key `make` targets:

| Command | What it does |
|---------|--------------|
| `make` / `make build` | Build + assemble → `build/MacAppFixer.app` |
| `make universal` | Universal (arm64 + x86_64) |
| `make test` | Unit tests |
| `make install` | Assemble + install to `/Applications` |
| `make dist` | `pkg` + `.app.zip` + `checksums.txt` (release) |

UI strings live in `Resources/{en,zh-Hans}.lproj/Localizable.strings` via `L.t("key")` — update both when changing text. The app deliberately runs **outside the App Sandbox** (a sandboxed process cannot write the quarantine xattr) and calls `listxattr` / `removexattr` in-process rather than shelling out to `/usr/bin/xattr`.

Release: write `docs/release-notes/vX.Y.Z.md`, then `make release VERSION=<x.y.z|patch|minor|major> MSG="…"`. The pushed tag triggers GitHub Actions to publish the Release. See [AGENTS.md](AGENTS.md).

## Sponsor

If this little tool helped you, consider buying the author a coffee ☕

Scan with **WeChat** or **Alipay** to support — your encouragement keeps the project going:

<table align="center" cellpadding="14">
  <tr>
    <td align="center"><img src="screenshots/wechat.jpg" width="180" alt="WeChat QR"></td>
    <td align="center"><img src="screenshots/alipay.jpg" width="180" alt="Alipay QR"></td>
  </tr>
  <tr>
    <td align="center">WeChat Pay</td>
    <td align="center">Alipay</td>
  </tr>
</table>

> The in-app "Sponsor ♥" button doesn't open a dialog — it just links to this repository page in your default browser.

## License

[MIT](LICENSE) © 2026 iamxz
