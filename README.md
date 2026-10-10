[![CI](https://github.com/iamxz/MacUnblockApp/actions/workflows/ci.yml/badge.svg)](https://github.com/iamxz/MacUnblockApp/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/iamxz/MacUnblockApp)](https://github.com/iamxz/MacUnblockApp/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# MacUnblock

**English** | [简体中文](README.zh-CN.md)

<img src="screenshots/icon.png" width="112" alt="MacUnblock app icon">

A tiny macOS utility: drag in an installer — or pick one with “Choose File…” — and it removes the quarantine attributes (`com.apple.quarantine`, etc.) in one click, so the “damaged / unverified developer” warning goes away.

It supports all the common macOS installer formats: `.app`, `.pkg`, `.mpkg`, `.dmg`, `.ipa`, `.appex`.

The UI is **bilingual (English / Simplified Chinese)** and follows your macOS language settings automatically — no manual switch.

## Features

- **Drag & drop**: drop `.app`, `.pkg`, `.dmg`, … straight onto the window
- **Choose File**: click the drop area or the “Choose File…” button (multi-select supported)
- **Batch**: handle several files at once
- **Recursive cleanup**: removes `com.apple.quarantine`, `com.apple.provenance`, … from every file inside a bundle
- **Preserves useful metadata**: leaves `com.apple.FinderInfo` / `com.apple.ResourceFork` untouched, so Finder icons and tags stay intact
- **Bilingual UI**: switches automatically with the system language
- **Fully local, no network**: no connections, no web pages, no external scripts

## Supported formats

| Format | Description |
|--------|-------------|
| `.app` | macOS application (bundle) |
| `.pkg` | macOS installer package |
| `.mpkg` | Multi-package installer |
| `.dmg` | Disk image |
| `.ipa` | iOS app package |
| `.appex` | App extension (bundle) |

## Requirements

- macOS 12.0+ (Monterey)
- Xcode Command Line Tools to build (`swift` / `xcrun`)

## Install

### Option 1: Download (recommended)

Grab the latest `.pkg` from [GitHub Releases](https://github.com/iamxz/MacUnblockApp/releases) and double-click to install into `/Applications/MacUnblock.app`; or download the `.app.zip`, unzip and drag it into Applications.

Verify the download:

```sh
shasum -a 256 -c checksums.txt
```

> The app is **ad-hoc signed**, and the package is **unsigned and not notarized**. The first launch may be blocked by Gatekeeper — either:
> - right-click the pkg → “Open”, or
> - System Settings → “Privacy & Security” → “Open Anyway”.

### Option 2: Build from source

```bash
git clone https://github.com/iamxz/MacUnblockApp.git
cd MacUnblockApp
make install      # build → sign → install to /Applications/MacUnblock.app
```

## Build

The project uses **Swift Package Manager** (see `Package.swift`): `swift build` produces the executable, then `make assemble` wraps it into a `.app` (copying `Info.plist`, the icon, `*.lproj` and `entitlements` from `Resources/` and ad-hoc signing it).

| Command | What it does |
|---------|--------------|
| `make` / `make build` | Build + assemble, output in `build/MacUnblock.app` |
| `make universal` | Universal (arm64 + x86_64) build + assemble |
| `make test` | Run unit tests |
| `make install` | Assemble + install to `/Applications` |
| `make run` | Install, then open the app |
| `make status` | Show install & version status |
| `make clean` | Remove `.build/` and `build/` |
| `make uninstall` | Move to Trash and unregister (recoverable) |
| `make pkg` | Universal build + `.pkg` |
| `make dist` | `pkg` + `.app.zip` + `checksums.txt` (for release) |

Or use SPM directly:

```bash
swift build           # compile only → .build/release/MacUnblock
swift test            # run unit tests
make assemble         # compile + assemble → build/MacUnblock.app
```

## Usage

1. Open `/Applications/MacUnblock.app`
2. **Drag** a `.app` / `.pkg` / `.dmg` … onto the drop area, or **click the drop area / “Choose File…”** and pick files (⌘ / ⇧ to multi-select)
3. The app removes the quarantine attributes and shows the result at the bottom

## Localization (i18n)

No UI string is hard-coded to a language. Everything is read through `NSLocalizedString` from `*.lproj/Localizable.strings`:

```
Sources/MacUnblockCore/
└── Localization.swift                  # L.t("key") entry point

Resources/
├── en.lproj/Localizable.strings        # English (development language / fallback)
└── zh-Hans.lproj/Localizable.strings   # Simplified Chinese
```

During the build these `*.lproj` folders are copied into `MacUnblock.app/Contents/Resources/` and read from the main bundle at runtime.

`Info.plist` declares the supported languages via `CFBundleLocalizations` and the fallback via `CFBundleDevelopmentRegion`. macOS picks the best match from your “System Settings → General → Language & Region” preferences: Chinese systems get Chinese, English systems get English, everything else falls back to English.

**When adding or changing UI strings**, update both `en.lproj` and `zh-Hans.lproj` (there is a checklist item for this in the PR template).

## How it works

When macOS downloads an installer it adds the `com.apple.quarantine` extended attribute, which causes:

- `.app` to show “unverified developer” or “damaged, move to Trash”
- `.pkg` / `.mpkg` to show “cannot be opened because it is from an unidentified developer”
- `.dmg` mounting to be blocked

This app calls libsystem `listxattr` / `removexattr` in-process and recursively strips the quarantine attributes from the file and everything inside a bundle.

### Removed attributes

| Attribute | Description |
|-----------|-------------|
| `com.apple.quarantine` | Quarantine flag on downloaded files |
| `com.apple.provenance` | Provenance (may be SIP-protected; failure is harmless) |
| Other xattrs | Removed recursively, except `com.apple.FinderInfo` / `com.apple.ResourceFork` are preserved (Finder icon/tags metadata) |

### Key design notes

1. **The main app must not use App Sandbox.**
   `/System/Library/Sandbox/Profiles/application.sb` hard-codes
   `(deny file-write-xattr (xattr "com.apple.quarantine"))`.
   No sandboxed process may write the quarantine attribute, and entitlements cannot bypass it.
   That's why `MacUnblock.entitlements` is empty and the app runs outside the sandbox.

2. **It does not shell out to `/usr/bin/xattr`.**
   The sandbox extension the parent process gets from a drag/drop is not inherited by a child
   started via `Process`, so the child hits `EPERM` — the source of the old
   `xattr: [Errno 1] Operation not permitted` error. Calling the native APIs in-process fixes it.

## FAQ

**Q: I get “Permission denied (Operation not permitted)”.**
If the file is in a protected folder (Desktop, Downloads, Documents), macOS shows an authorization prompt on first access — click “Allow”. If you previously denied it, enable MacUnblock in System Settings → Privacy & Security → Full Disk Access and relaunch.

**Q: Why am I asked to authorize again after each rebuild?**
Because the app is ad-hoc signed, the signature changes on every rebuild and macOS treats it as a new app. Keep it in `/Applications` and avoid frequent rebuilds to reduce the prompts.

**Q: The UI language is wrong.**
The app follows the system language. Change your preferred language in System Settings → General → Language & Region and relaunch the app.

## Alternative (without installing the app)

You can also do it manually in Terminal:

```bash
# .app bundle
xattr -r -d com.apple.quarantine /path/to/YourApp.app

# .pkg installer
xattr -d com.apple.quarantine /path/to/Installer.pkg

# .dmg disk image
xattr -d com.apple.quarantine /path/to/DiskImage.dmg
```

This app simply wraps those commands in a GUI.

## Project layout

```
MacUnblockApp/
├── .github/                    # CI / Release workflows, issue & PR templates
├── Package.swift               # Swift Package Manager manifest
├── Sources/
│   ├── MacUnblockCore/         # Logic layer (no AppKit, unit-testable)
│   │   ├── Xattr.swift         # xattr read/write + errno mapping
│   │   ├── Unblocker.swift     # Recursive unblock + supported formats
│   │   └── Localization.swift  # L.t(...) entry point
│   └── MacUnblock/             # App layer
│       ├── main.swift          # Entry point
│       ├── AppDelegate.swift   # Main window, drag & drop orchestration
│       └── DropAreaView.swift  # Drop-area view
├── Resources/                  # Copied into the .app at build time
│   ├── Info.plist              # App metadata (incl. CFBundleLocalizations)
│   ├── MacUnblock.icns         # App icon
│   ├── MacUnblock.entitlements # Empty (intentionally not sandboxed)
│   ├── en.lproj/               # English strings
│   └── zh-Hans.lproj/          # Chinese strings
├── Tests/MacUnblockCoreTests/  # Logic-layer unit tests
├── docs/release-notes/         # Per-version release notes (Release body source)
├── scripts/release.sh          # Release script
├── Makefile                    # Build / assemble / install / release wrapper
├── CHANGELOG.md                # Changelog
├── CONTRIBUTING.md             # Contributing guide
└── LICENSE                     # MIT
```

## Releasing

Write the release notes in `docs/release-notes/vX.Y.Z.md` (they become the GitHub Release body), then:

```sh
make release VERSION=<x.y.z|patch|minor|major> MSG="commit message"
```

The script builds to verify, bumps both version fields in `Resources/Info.plist`, commits, tags `vX.Y.Z` and pushes. The tag triggers GitHub Actions to build `.pkg` / `.app.zip` / `checksums.txt` and publish the Release. See [AGENTS.md](AGENTS.md).

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). See [CHANGELOG.md](CHANGELOG.md) for history.

## License

[MIT](LICENSE) © 2026 iamxz
