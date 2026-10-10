import Cocoa
import FinderSync

class SyncDelegate: FIFinderSync {

    /// 与主应用约定的 URL Scheme（主应用 Info.plist 中注册）
    private static let urlScheme = "macunblock"

    override init() {
        super.init()
        let dir = FIFinderSyncController.default()
        dir.directoryURLs = [URL(fileURLWithPath: "/")]
    }

    // MARK: - Toolbar Items (optional, for Finder toolbar button)

    override var toolbarItemName: String {
        return "MacUnblock"
    }

    override var toolbarItemToolTip: String {
        return "解除 macOS 应用安装限制"
    }

    override var toolbarItemImage: NSImage {
        return NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "MacUnblock") ?? NSImage()
    }

    // MARK: - Supported Extensions

    /// 所有支持的安装包格式
    static let supportedExtensions: Set<String> = [
        "app",    // 应用程序
        "pkg",    // 安装包
        "mpkg",   // 多包安装包
        "dmg",    // 磁盘映像
        "ipa",    // iOS 应用包
        "appex",  // 应用扩展
    ]

    func isSupportedFile(_ url: URL) -> Bool {
        return SyncDelegate.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Menu Items

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        let targetedURL = FIFinderSyncController.default().targetedURL()

        let hasSupported = selectedURLs.contains(where: { isSupportedFile($0) })
        let targetedIsSupported = targetedURL.map { isSupportedFile($0) } ?? false

        if !hasSupported && !targetedIsSupported {
            return nil
        }

        let menu = NSMenu(title: "MacUnblock")
        menu.addItem(withTitle: "🔓 解除安装限制", action: #selector(unblockApp(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "🔍 查看扩展属性", action: #selector(showXattrInfo(_:)), keyEquivalent: "")
        return menu
    }

    // MARK: - Actions
    //
    // Finder 扩展必须运行在 App Sandbox 中，而沙箱进程被系统禁止写
    // com.apple.quarantine（application.sb 里硬编码了 deny file-write-xattr），
    // 因此这里不做实际处理，只把请求通过 macunblock:// 转交给不带沙箱的主应用。

    @IBAction func unblockApp(_ sender: AnyObject?) {
        let urls = selectedSupportedURLs()
        guard !urls.isEmpty else { return }
        forward(action: "unblock", urls: urls)
    }

    @IBAction func showXattrInfo(_ sender: AnyObject?) {
        let urls = selectedSupportedURLs()
        guard !urls.isEmpty else { return }
        forward(action: "info", urls: urls)
    }

    // MARK: - Helpers

    private func selectedSupportedURLs() -> [URL] {
        let selected = (FIFinderSyncController.default().selectedItemURLs() ?? []).filter {
            isSupportedFile($0)
        }
        if !selected.isEmpty { return selected }

        if let targeted = FIFinderSyncController.default().targetedURL(), isSupportedFile(targeted) {
            return [targeted]
        }
        return []
    }

    private func forward(action: String, urls: [URL]) {
        var failed: [String] = []

        for url in urls {
            var components = URLComponents()
            components.scheme = SyncDelegate.urlScheme
            components.host = action
            components.queryItems = [URLQueryItem(name: "path", value: url.path)]

            guard let request = components.url, NSWorkspace.shared.open(request) else {
                failed.append(url.lastPathComponent)
                continue
            }
        }

        if !failed.isEmpty {
            showAlert(
                title: "无法启动 MacUnblock",
                body: "以下文件没能交给主应用处理：\n\(failed.joined(separator: "\n"))\n\n"
                    + "请先手动打开 MacUnblock.app，再把文件拖进窗口完成解除。"
            )
        }
    }

    // MARK: - Alert

    func showAlert(title: String, body: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = title
            alert.informativeText = body
            alert.addButton(withTitle: "好的")

            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
