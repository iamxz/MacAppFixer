import Cocoa
import MacAppFixerCore

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    /// 赞助入口只做一件事：跳到仓库页，收款码由 README 展示
    static let repoURL = URL(string: "https://github.com/iamxz/MacAppFixer")!

    var window: NSWindow!
    var dropAreaView: DropAreaView!
    var resultLabel: NSTextField!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        createMainWindow()
    }

    func createMainWindow() {
        if window != nil { return }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MacAppFixer"
        window.minSize = NSSize(width: 460, height: 500)
        window.contentView = createContentView()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createContentView() -> NSView {
        let containerView = NSView()

        // --- 顶部图标和标题 ---
        let iconImageView = NSImageView()
        iconImageView.image = NSImage(
            systemSymbolName: "shield.lefthalf.filled",
            accessibilityDescription: "App Icon"
        )
        iconImageView.contentTintColor = .controlAccentColor
        iconImageView.symbolConfiguration = .init(pointSize: 40, weight: .regular)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "MacAppFixer")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = NSTextField(labelWithString: L.t("window.subtitle"))
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        // --- 拖拽区域（同时支持点击唤起文件选择器）---
        dropAreaView = DropAreaView()
        dropAreaView.appDelegate = self
        dropAreaView.translatesAutoresizingMaskIntoConstraints = false
        dropAreaView.wantsLayer = true
        dropAreaView.layer?.cornerRadius = 16
        dropAreaView.layer?.borderWidth = 2
        dropAreaView.layer?.borderColor = NSColor.separatorColor.cgColor
        dropAreaView.layer?.backgroundColor = NSColor.alternatingContentBackgroundColors.first?.cgColor

        let dropIcon = NSImageView()
        dropIcon.image = NSImage(systemSymbolName: "arrow.down.doc", accessibilityDescription: nil)
        dropIcon.contentTintColor = .secondaryLabelColor
        dropIcon.symbolConfiguration = .init(pointSize: 36, weight: .regular)
        dropIcon.translatesAutoresizingMaskIntoConstraints = false

        let dropLabel = NSTextField(labelWithString: L.t("drop.title"))
        dropLabel.font = .systemFont(ofSize: 14, weight: .medium)
        dropLabel.textColor = .secondaryLabelColor
        dropLabel.alignment = .center
        dropLabel.translatesAutoresizingMaskIntoConstraints = false

        let dropSubLabel = NSTextField(labelWithString: L.t("drop.subtitle"))
        dropSubLabel.font = .systemFont(ofSize: 11)
        dropSubLabel.textColor = .tertiaryLabelColor
        dropSubLabel.alignment = .center
        dropSubLabel.lineBreakMode = .byWordWrapping
        dropSubLabel.maximumNumberOfLines = 0
        dropSubLabel.translatesAutoresizingMaskIntoConstraints = false

        dropAreaView.addSubview(dropIcon)
        dropAreaView.addSubview(dropLabel)
        dropAreaView.addSubview(dropSubLabel)

        NSLayoutConstraint.activate([
            dropIcon.topAnchor.constraint(equalTo: dropAreaView.topAnchor, constant: 34),
            dropIcon.centerXAnchor.constraint(equalTo: dropAreaView.centerXAnchor),
            dropLabel.topAnchor.constraint(equalTo: dropIcon.bottomAnchor, constant: 12),
            dropLabel.centerXAnchor.constraint(equalTo: dropAreaView.centerXAnchor),
            dropSubLabel.topAnchor.constraint(equalTo: dropLabel.bottomAnchor, constant: 6),
            dropSubLabel.centerXAnchor.constraint(equalTo: dropAreaView.centerXAnchor),
            dropSubLabel.leadingAnchor.constraint(greaterThanOrEqualTo: dropAreaView.leadingAnchor, constant: 12),
            dropSubLabel.trailingAnchor.constraint(lessThanOrEqualTo: dropAreaView.trailingAnchor, constant: -12),
        ])

        // --- 选择文件按钮 ---
        let chooseButton = NSButton(title: L.t("button.choose"), target: self, action: #selector(chooseFiles))
        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .large
        chooseButton.keyEquivalent = "\r"   // 回车即打开选择器
        chooseButton.translatesAutoresizingMaskIntoConstraints = false

        // --- 赞助按钮（用默认浏览器打开 GitHub 仓库页，收款码在 README 里）---
        let sponsorButton = NSButton(title: L.t("sponsor.title"), target: self, action: #selector(openRepoPage))
        sponsorButton.bezelStyle = .rounded
        sponsorButton.controlSize = .small
        sponsorButton.toolTip = L.t("sponsor.tooltip")
        sponsorButton.translatesAutoresizingMaskIntoConstraints = false

        // --- 结果显示区域 ---
        resultLabel = NSTextField(labelWithString: "")
        resultLabel.font = .systemFont(ofSize: 12)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.alignment = .center
        resultLabel.lineBreakMode = .byWordWrapping
        resultLabel.maximumNumberOfLines = 0
        resultLabel.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(dropAreaView)
        containerView.addSubview(chooseButton)
        containerView.addSubview(sponsorButton)
        containerView.addSubview(resultLabel)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 22),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            descLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            dropAreaView.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 18),
            dropAreaView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            dropAreaView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            dropAreaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),

            chooseButton.topAnchor.constraint(equalTo: dropAreaView.bottomAnchor, constant: 14),
            chooseButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            sponsorButton.topAnchor.constraint(equalTo: chooseButton.bottomAnchor, constant: 10),
            sponsorButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            resultLabel.topAnchor.constraint(equalTo: sponsorButton.bottomAnchor, constant: 12),
            resultLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            resultLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -20),
        ])

        return containerView
    }

    // MARK: - 业务逻辑

    func showResult(_ text: String, color: NSColor) {
        resultLabel.stringValue = text
        resultLabel.textColor = color
    }

    /// 用默认浏览器打开仓库页，赞助方式（含收款码）看 README。
    @objc func openRepoPage() {
        NSWorkspace.shared.open(Self.repoURL)
    }

    /// 文件选择器（第二种入口：点击拖拽区域或「选择文件…」按钮）
    @objc func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = L.t("panel.title")
        panel.message = L.t("panel.message")
        panel.prompt = L.t("panel.prompt")
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true              // .app 本质是目录，允许选中
        panel.treatsFilePackagesAsDirectories = false  // 让 .app 以「文件」形式出现在面板里
        panel.resolvesAliases = true
        panel.delegate = self

        let response = panel.runModal()
        guard response == .OK, !panel.urls.isEmpty else { return }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        unblockFiles(panel.urls)
    }

    func unblockFiles(_ urls: [URL]) {
        let supportedURLs = urls.filter { Unblocker.isSupported($0) }

        if supportedURLs.isEmpty {
            showResult(L.t("result.unsupported"), color: .systemOrange)
            return
        }

        showResult(L.t("result.processing", supportedURLs.count), color: .secondaryLabelColor)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var successCount = 0
            var failCount = 0
            var messages: [String] = []

            for url in supportedURLs {
                let result = Unblocker.unblock(url)
                if result.ok {
                    successCount += 1
                } else {
                    failCount += 1
                }
                messages.append(L.t("result.file_entry", url.lastPathComponent, result.message))
            }

            DispatchQueue.main.async {
                guard let self = self else { return }

                if failCount == 0 {
                    if supportedURLs.count == 1 {
                        self.showResult(L.t("result.single_ok", supportedURLs[0].lastPathComponent, messages[0]), color: .systemGreen)
                    } else {
                        self.showResult(L.t("result.multi_ok", successCount), color: .systemGreen)
                    }
                } else if successCount == 0 {
                    self.showResult(L.t("result.all_failed", messages.joined(separator: "\n")), color: .systemRed)
                } else {
                    self.showResult(L.t("result.partial", successCount, failCount, messages.joined(separator: "\n")), color: .systemOrange)
                }
            }
        }
    }

    /// 在结果区域列出文件的扩展属性（辅助排查用）
    func showXattrInfo(_ urls: [URL]) {
        guard let url = urls.first else { return }
        let attrs = Xattr.list(url.path)
        if attrs.isEmpty {
            showResult(L.t("xattr.none", url.lastPathComponent), color: .secondaryLabelColor)
        } else {
            showResult(L.t("xattr.list", url.lastPathComponent, attrs.joined(separator: ", ")), color: .secondaryLabelColor)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: NSOpenSavePanelDelegate {
    /// 只让受支持的文件可点选；目录保持可用（否则进不去、也选不了 .app）
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return true
        }
        return Unblocker.isSupported(url)
    }
}
