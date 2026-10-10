import Cocoa
import Darwin

// MARK: - 扩展属性（xattr）工具
//
// 为什么不用 /usr/bin/xattr 子进程，也不走 App Sandbox：
//
// 1) App Sandbox 的配置文件里硬编码了
//      (deny file-write-xattr (xattr "com.apple.quarantine"))
//    （见 /System/Library/Sandbox/Profiles/application.sb）
//    也就是说任何沙箱进程——包括 Finder 扩展——都不可能移除隔离属性，
//    这不是 entitlements 能解决的问题，所以主应用必须运行在沙箱之外。
//
// 2) 通过 Process 启动 /usr/bin/xattr 时，父进程从拖拽/选择文件拿到的
//    sandbox extension 不会继承给子进程，子进程访问该文件会直接 EPERM。
//    旧的报错 "xattr: [Errno 1] Operation not permitted" 就来自这里。
//
// 因此这里直接调用 libsystem 的 listxattr / removexattr，在当前进程内完成。

enum Xattr {
    /// errno 93 == ENOATTR（属性不存在）
    private static let enoattr: Int32 = 93

    /// 这些属性需要保留：删掉会丢失 Finder 图标 / 标签 / 资源分支等信息
    static let preserved: Set<String> = ["com.apple.ResourceFork", "com.apple.FinderInfo"]

    static func list(_ path: String) -> [String] {
        let size = listxattr(path, nil, 0, 0)
        guard size > 0 else { return [] }

        var buffer = [CChar](repeating: 0, count: size)
        let count = listxattr(path, &buffer, size, 0)
        guard count > 0 else { return [] }

        let data = Data(bytes: buffer, count: count)
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.components(separatedBy: "\0").filter { !$0.isEmpty }
    }

    /// 成功（含"属性本就不存在"）返回 nil，失败返回 POSIX errno
    static func remove(_ name: String, at path: String) -> Int32? {
        if removexattr(path, name, 0) == 0 { return nil }
        let code = errno
        return code == enoattr ? nil : code
    }

    /// 把 errno 翻译成用户能看懂、能照着做的提示
    static func describe(_ code: Int32) -> String {
        let text = String(cString: strerror(code))
        switch code {
        case EPERM, EACCES:
            return "权限不足（\(text)）。请在「系统设置 → 隐私与安全性 → 完全磁盘访问权限」中勾选 MacUnblock 后重试；"
                + "若文件在「桌面 / 下载 / 文稿」等受保护目录，首次访问时请在弹出的系统提示中点击「允许」"
        case EROFS:
            return "文件系统为只读，无法修改扩展属性"
        case ENOTSUP:
            return "该文件系统不支持扩展属性"
        default:
            return "\(text)（errno \(code)）"
        }
    }
}

// MARK: - 解除限制

struct UnblockResult {
    let ok: Bool
    let message: String
}

enum Unblocker {
    /// 递归移除文件（或 bundle）上的限制属性
    static func unblock(_ fileURL: URL) -> UnblockResult {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            return UnblockResult(ok: false, message: "文件不存在或已被移动")
        }

        // bundle（.app / .appex / .mpkg）需要递归处理，扁平文件只处理自身
        var targets: [URL] = [fileURL]
        if isDirectory.boolValue,
           let enumerator = fm.enumerator(at: fileURL, includingPropertiesForKeys: nil) {
            for case let item as URL in enumerator {
                targets.append(item)
            }
        }

        var removed = 0
        var failureCount = 0
        var firstError: Int32?

        for target in targets {
            for name in Xattr.list(target.path) where !Xattr.preserved.contains(name) {
                if let code = Xattr.remove(name, at: target.path) {
                    failureCount += 1
                    if firstError == nil { firstError = code }
                } else {
                    removed += 1
                }
            }
        }

        if removed == 0 {
            if let code = firstError {
                return UnblockResult(ok: false, message: Xattr.describe(code))
            }
            return UnblockResult(ok: true, message: "本就没有限制属性，无需处理")
        }

        if failureCount > 0, let code = firstError {
            return UnblockResult(
                ok: true,
                message: "已移除 \(removed) 个扩展属性，另有 \(failureCount) 个无法移除（\(String(cString: strerror(code)))），通常不影响使用"
            )
        }
        return UnblockResult(ok: true, message: "已移除 \(removed) 个扩展属性")
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var dropAreaView: DropAreaView!
    var resultLabel: NSTextField!
    var statusLabel: NSTextField!
    var hintLabel: NSTextField!

    /// 支持的安装包格式
    static let supportedExtensions: Set<String> = [
        "app", "pkg", "mpkg", "dmg", "ipa", "appex",
    ]

    /// 与 Finder 扩展通信用的 URL Scheme（主应用 Info.plist 中注册）
    static let urlScheme = "macunblock"

    /// Finder 扩展的标识，需与 build.sh / Xcode 工程保持一致
    static let finderSyncBundleID = "com.macunblock.app.FinderSync"
    static let finderSyncBundleName = "MacUnblockAppFinderSync.appex"

    /// 只允许处理这些位置下的文件：用户主目录、应用程序目录、挂载的磁盘映像
    private let allowedRoots = [NSHomeDirectory(), "/Applications", "/Volumes"]

    /// 启动期间到达的 URL 请求。
    /// AppKit 可能在 applicationDidFinishLaunching 还没返回时就把 macunblock:// 事件回调进来，
    /// 那时界面尚未建好，直接处理会访问到未初始化的 UI 对象，所以先入队。
    private var pendingOpenURLs: [URL] = []
    private var isLaunched = false

    /// 「引导设置」面板控制器
    private var setupGuide: SetupGuideController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        createMainWindow()
        isLaunched = true

        let queued = pendingOpenURLs
        pendingOpenURLs.removeAll()
        if !queued.isEmpty {
            handleOpenURLs(queued)
        }

        // 调试/支持用：open -a MacUnblock --args --setup-guide 直接弹出引导面板
        if CommandLine.arguments.contains("--setup-guide") {
            showSetupGuide()
        }
    }

    func createMainWindow() {
        if window != nil { return }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MacUnblock"
        window.minSize = NSSize(width: 480, height: 640)
        window.contentView = createContentView()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createContentView() -> NSView {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // --- 顶部图标和标题 ---
        let iconImageView = NSImageView()
        iconImageView.image = NSImage(
            systemSymbolName: "shield.lefthalf.filled",
            accessibilityDescription: "App Icon"
        )
        iconImageView.contentTintColor = .controlAccentColor
        iconImageView.symbolConfiguration = .init(pointSize: 40, weight: .regular)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "MacUnblock")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = NSTextField(labelWithString: "拖拽文件、点击选择，或在 Finder 中右键 —— 三种方式任选")
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
        dropAreaView.registerForDraggedTypes([.fileURL])

        // 拖拽区域内部内容
        let dropIcon = NSImageView()
        dropIcon.image = NSImage(systemSymbolName: "arrow.down.doc", accessibilityDescription: nil)
        dropIcon.contentTintColor = .secondaryLabelColor
        dropIcon.symbolConfiguration = .init(pointSize: 36, weight: .regular)
        dropIcon.translatesAutoresizingMaskIntoConstraints = false

        let dropLabel = NSTextField(labelWithString: "将 .app .pkg .dmg 等文件拖到此处")
        dropLabel.font = .systemFont(ofSize: 14, weight: .medium)
        dropLabel.textColor = .secondaryLabelColor
        dropLabel.alignment = .center
        dropLabel.translatesAutoresizingMaskIntoConstraints = false

        let dropSubLabel = NSTextField(labelWithString: "也可以直接点这里选择文件\n支持 .app .pkg .mpkg .dmg .ipa .appex")
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
            dropIcon.topAnchor.constraint(equalTo: dropAreaView.topAnchor, constant: 30),
            dropIcon.centerXAnchor.constraint(equalTo: dropAreaView.centerXAnchor),
            dropLabel.topAnchor.constraint(equalTo: dropIcon.bottomAnchor, constant: 12),
            dropLabel.centerXAnchor.constraint(equalTo: dropAreaView.centerXAnchor),
            dropSubLabel.topAnchor.constraint(equalTo: dropLabel.bottomAnchor, constant: 6),
            dropSubLabel.centerXAnchor.constraint(equalTo: dropAreaView.centerXAnchor),
            dropSubLabel.leadingAnchor.constraint(greaterThanOrEqualTo: dropAreaView.leadingAnchor, constant: 12),
            dropSubLabel.trailingAnchor.constraint(lessThanOrEqualTo: dropAreaView.trailingAnchor, constant: -12),
        ])

        // --- 选择文件按钮 ---
        let chooseButton = NSButton(title: "选择文件…", target: self, action: #selector(chooseFiles))
        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .large
        chooseButton.keyEquivalent = "\r"   // 回车即打开选择器
        chooseButton.translatesAutoresizingMaskIntoConstraints = false

        // --- 结果显示区域 ---
        resultLabel = NSTextField(labelWithString: "")
        resultLabel.font = .systemFont(ofSize: 12)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.alignment = .center
        resultLabel.lineBreakMode = .byWordWrapping
        resultLabel.maximumNumberOfLines = 0
        resultLabel.translatesAutoresizingMaskIntoConstraints = false

        // --- 分割线 ---
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        // --- Finder 扩展状态 ---
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let enableButton = NSButton(title: "引导设置…", target: self, action: #selector(showSetupGuide))
        enableButton.bezelStyle = .rounded
        enableButton.controlSize = .regular
        enableButton.translatesAutoresizingMaskIntoConstraints = false

        let restartFinderButton = NSButton(title: "重启 Finder", target: self, action: #selector(restartFinder))
        restartFinderButton.bezelStyle = .rounded
        restartFinderButton.controlSize = .regular
        restartFinderButton.translatesAutoresizingMaskIntoConstraints = false

        let refreshButton = NSButton(title: "重新检测状态", target: self, action: #selector(refreshStatus))
        refreshButton.bezelStyle = .rounded
        refreshButton.controlSize = .regular
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow = NSStackView(views: [enableButton, restartFinderButton, refreshButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        hintLabel = NSTextField(labelWithString: "三种方式：① 拖拽文件到窗口 ② 点击「选择文件…」 ③ 在 Finder 中右键安装包 → 「🔓 解除安装限制」\n第 ③ 种需要先在「系统设置 → 通用 → 登录项与扩展」中开启 MacUnblock 扩展，然后重启 Finder 生效。")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .center
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        // --- 布局 ---
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(dropAreaView)
        containerView.addSubview(chooseButton)
        containerView.addSubview(resultLabel)
        containerView.addSubview(separator)
        containerView.addSubview(statusLabel)
        containerView.addSubview(buttonRow)
        containerView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            // 顶部图标
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            descLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            // 拖拽区域
            dropAreaView.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 16),
            dropAreaView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            dropAreaView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            dropAreaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),

            // 选择文件按钮
            chooseButton.topAnchor.constraint(equalTo: dropAreaView.bottomAnchor, constant: 12),
            chooseButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            // 结果
            resultLabel.topAnchor.constraint(equalTo: chooseButton.bottomAnchor, constant: 12),
            resultLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            // 分割线
            separator.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            // 扩展状态
            statusLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            buttonRow.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            buttonRow.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            hintLabel.topAnchor.constraint(equalTo: buttonRow.bottomAnchor, constant: 10),
            hintLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            hintLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16),
        ])

        updateStatusLabel()

        return containerView
    }

    // MARK: - Unblock Logic

    func isSupportedFile(_ url: URL) -> Bool {
        return AppDelegate.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    func showResult(_ text: String, color: NSColor) {
        resultLabel.stringValue = text
        resultLabel.textColor = color
    }

    // MARK: - 选择文件（第三种方式：文件选择器）

    @objc func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "选择要解除限制的安装包"
        panel.message = "支持 .app / .pkg / .mpkg / .dmg / .ipa / .appex，可按住 ⌘ 或 ⇧ 多选"
        panel.prompt = "解除限制"
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
        let supportedURLs = urls.filter { isSupportedFile($0) }

        if supportedURLs.isEmpty {
            showResult("⚠️ 不支持的文件格式，请拖入或用「选择文件…」选取 .app .pkg .dmg .mpkg .ipa .appex 文件", color: .systemOrange)
            return
        }

        showResult("⏳ 正在处理 \(supportedURLs.count) 个文件...", color: .secondaryLabelColor)

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
                messages.append("\(url.lastPathComponent)：\(result.message)")
            }

            DispatchQueue.main.async {
                guard let self = self else { return }

                if failCount == 0 {
                    if supportedURLs.count == 1 {
                        self.showResult("✅ 已解除「\(supportedURLs[0].lastPathComponent)」的安装限制\n\(messages[0])，现在可以正常打开了。", color: .systemGreen)
                    } else {
                        self.showResult("✅ 已成功解除 \(successCount) 个文件的安装限制", color: .systemGreen)
                    }
                } else if successCount == 0 {
                    self.showResult("❌ 解除失败\n" + messages.joined(separator: "\n"), color: .systemRed)
                } else {
                    self.showResult("⚠️ 成功 \(successCount) 个，失败 \(failCount) 个\n" + messages.joined(separator: "\n"), color: .systemOrange)
                }
            }
        }
    }

    /// 在结果区域列出文件的扩展属性（Finder 扩展的「查看扩展属性」也走这里）
    func showXattrInfo(_ urls: [URL]) {
        guard let url = urls.first else { return }

        var lines: [String] = []
        var prefixes: [String] = [url.path]

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue,
           let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
            var count = 0
            for case let item as URL in enumerator {
                prefixes.append(item.path)
                count += 1
                if count >= 200 { break }   // 只展示前若干项，避免刷屏
            }
        }

        for path in prefixes {
            let attrs = Xattr.list(path)
            guard !attrs.isEmpty else { continue }
            let name = (path as NSString).lastPathComponent
            lines.append("\(name): \(attrs.joined(separator: ", "))")
            if lines.count >= 20 { break }
        }

        if lines.isEmpty {
            showResult("🔍 \(url.lastPathComponent)：没有扩展属性", color: .secondaryLabelColor)
        } else {
            showResult("🔍 \(url.lastPathComponent) 的扩展属性：\n" + lines.joined(separator: "\n"), color: .secondaryLabelColor)
        }
    }

    // MARK: - 从 Finder 扩展接收请求（macunblock://）

    func application(_ application: NSApplication, open urls: [URL]) {
        guard isLaunched else {
            pendingOpenURLs.append(contentsOf: urls)
            return
        }
        handleOpenURLs(urls)
    }

    func handleOpenURLs(_ urls: [URL]) {
        if window == nil { createMainWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        guard let url = urls.first else { return }
        guard url.scheme == AppDelegate.urlScheme else { return }

        let action = url.host ?? ""

        // macunblock://guide —— 打开「引导设置」面板。
        // 走 URL Scheme 的好处：应用已经在运行时也能触发（open -a --args 做不到）。
        if action == "guide" {
            showSetupGuide()
            return
        }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let path = items.first(where: { $0.name == "path" })?.value, !path.isEmpty else { return }

        let fileURL = URL(fileURLWithPath: path)

        guard allowedRoots.contains(where: { path.hasPrefix($0) }) else {
            showResult("⚠️ 出于安全考虑，只处理用户主目录、/Applications 与 /Volumes 下的文件\n\(path)", color: .systemOrange)
            return
        }
        guard isSupportedFile(fileURL) else {
            showResult("⚠️ 不支持的文件格式：\(fileURL.lastPathComponent)", color: .systemOrange)
            return
        }

        switch action {
        case "unblock":
            unblockFiles([fileURL])
        case "info":
            showXattrInfo([fileURL])
        default:
            break
        }
    }

    // MARK: - Shell Helpers

    @discardableResult
    func runTool(_ path: String, _ arguments: [String]) -> (launched: Bool, output: String, status: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            // 先读完输出再等待退出，避免管道写满导致死锁
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return (true, String(data: data, encoding: .utf8) ?? "", task.terminationStatus)
        } catch {
            return (false, error.localizedDescription, -1)
        }
    }

    // MARK: - Extension Status

    enum FinderExtensionState {
        case enabled        // 已注册且已启用
        case disabled       // 已注册但未启用
        case missing        // 应用包里根本没有 appex
        case undetectable   // 系统不允许查询（新版 macOS 的 pluginkit 需要授权）
    }

    var appexURL: URL? {
        guard let plugins = Bundle.main.builtInPlugInsURL else { return nil }
        let url = plugins.appendingPathComponent(AppDelegate.finderSyncBundleName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func currentExtensionState() -> FinderExtensionState {
        guard appexURL != nil else { return .missing }

        let probe = runTool("/usr/bin/pluginkit", ["-m", "-v", "-i", AppDelegate.finderSyncBundleID])
        guard probe.launched else { return .undetectable }

        let output = probe.output
        // 新版 macOS 收紧了 pluginkit 的查询权限：普通进程调用会直接拒绝
        if output.contains("unauthorized") || output.contains("not authorized") || output.contains("PKDiscoverAll") {
            return .undetectable
        }

        if let line = output.components(separatedBy: "\n")
            .first(where: { $0.contains(AppDelegate.finderSyncBundleID) }) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("+") { return .enabled }
            if trimmed.hasPrefix("-") { return .disabled }
            return .undetectable
        }

        // 查询正常但没有结果，说明扩展还没被系统登记
        return .disabled
    }

    /// 判断扩展是否真的被 Finder 加载了。
    /// 比 pluginkit 查询可靠得多 —— 新版 macOS 已不允许普通进程查询插件启用状态，
    /// 但"FinderSync 扩展进程在不在"是可以直接观察到的。
    func isExtensionProcessRunning() -> Bool {
        let probe = runTool("/usr/bin/pgrep", ["-f", AppDelegate.finderSyncBundleName])
        guard probe.launched, probe.status == 0 else { return false }
        return !probe.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateStatusLabel() {
        let locationHint = Bundle.main.bundlePath.hasPrefix("/Applications/")
            ? ""
            : "（当前运行位置：\((Bundle.main.bundlePath as NSString).abbreviatingWithTildeInPath)，建议先移到「应用程序」文件夹）"

        if isExtensionProcessRunning() {
            statusLabel.stringValue = "✅ Finder 扩展已加载，右键菜单可用"
            statusLabel.textColor = .systemGreen
            return
        }

        switch currentExtensionState() {
        case .enabled:
            statusLabel.stringValue = "⚠️ 扩展已启用但尚未被 Finder 加载\(locationHint)\n点「重启 Finder」让它生效"
            statusLabel.textColor = .systemOrange
        case .disabled:
            statusLabel.stringValue = "⏳ Finder 扩展尚未启用\(locationHint)\n点「引导设置…」按步骤开启，然后点「重启 Finder」"
            statusLabel.textColor = .systemOrange
        case .missing:
            statusLabel.stringValue = "❌ 应用包内缺少 Finder 扩展，请重新构建应用（./build.sh）"
            statusLabel.textColor = .systemRed
        case .undetectable:
            statusLabel.stringValue = "ℹ️ 当前系统不允许自动检测扩展状态\(locationHint)\n点「引导设置…」按步骤操作，再在 Finder 里右键验证"
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    /// 打开「引导设置」面板
    @objc func showSetupGuide() {
        if setupGuide == nil {
            setupGuide = SetupGuideController(app: self)
        }
        setupGuide?.present()
    }

    @objc func refreshStatus() {
        updateStatusLabel()
    }

    /// 扩展被启用 / 更新后，Finder 需要重新加载才会挂上右键菜单
    @objc func restartFinder() {
        _ = runTool("/usr/bin/killall", ["Finder"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.updateStatusLabel()
        }
    }

    /// 把扩展重新登记到 LaunchServices / PluginKit
    /// （系统设置里看不到 MacUnblock 条目时，多半是登记信息过期了）
    @objc func registerExtension() {
        guard let appex = appexURL else { return }

        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        if FileManager.default.isExecutableFile(atPath: lsregister) {
            _ = runTool(lsregister, ["-f", appex.path])
        }

        // pluginkit -a 在受限系统上依然可用；-e use 在新系统会被拒绝，失败忽略即可
        _ = runTool("/usr/bin/pluginkit", ["-a", appex.path])
        _ = runTool("/usr/bin/pluginkit", ["-e", "use", "-i", AppDelegate.finderSyncBundleID])
    }

    @objc func enableExtension() {
        registerExtension()
        openSystemSettings()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.updateStatusLabel()
        }
    }

    @objc func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",            // macOS 13+：登录项与扩展
            "x-apple.systempreferences:com.apple.extensionkit.AppExtensionManagement",      // macOS 15+：扩展管理
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",                    // macOS 12：扩展
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

// MARK: - 文件选择面板

extension AppDelegate: NSOpenSavePanelDelegate {
    /// 只让受支持的文件可点选；目录保持可用（否则进不去、也选不了 .app）
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return true
        }
        return isSupportedFile(url)
    }
}

// MARK: - Drop Area View

class DropAreaView: NSView {
    weak var appDelegate: AppDelegate?
    private var isDragOver = false

    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL])
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    // MARK: - 点击 = 打开文件选择器

    /// 内部图标/文字是纯装饰，让整个区域统一接收点击与拖拽
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let parent = superview else { return nil }
        let local = convert(point, from: parent)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        appDelegate?.chooseFiles()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = extractURLs(from: sender)
        let hasSupported = urls.contains(where: { AppDelegate.supportedExtensions.contains($0.pathExtension.lowercased()) })

        if hasSupported {
            isDragOver = true
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            return .copy
        } else {
            isDragOver = false
            layer?.borderColor = NSColor.systemRed.cgColor
            return []
        }
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return isDragOver ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragOver = false
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.alternatingContentBackgroundColors.first?.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = extractURLs(from: sender)
        let supported = urls.filter { AppDelegate.supportedExtensions.contains($0.pathExtension.lowercased()) }

        if supported.isEmpty {
            return false
        }

        isDragOver = false
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.alternatingContentBackgroundColors.first?.cgColor

        if let app = NSApp.delegate as? AppDelegate {
            app.unblockFiles(supported)
        }

        return true
    }

    private func extractURLs(from sender: NSDraggingInfo) -> [URL] {
        // 用 readObjects 而不是 string(forType:)，让系统正确传递文件访问权限
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
            return urls
        }

        // 兜底：老式 pasteboard 读取
        guard let items = sender.draggingPasteboard.pasteboardItems else { return [] }
        return items.compactMap { item in
            item.string(forType: .fileURL).flatMap { URL(string: $0) }
        }
    }
}
