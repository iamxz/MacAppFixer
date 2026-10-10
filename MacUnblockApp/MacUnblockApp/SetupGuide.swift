import Cocoa

/// 「引导设置」面板
///
/// 用一张 sheet 把"开启 Finder 右键菜单"拆成 4 步，每步给出**该点哪里**和**现在是什么状态**：
///  1. 应用是否在「应用程序」文件夹（扩展只有被系统发现才可能被登记）
///  2. 系统设置里开启 MacUnblock 扩展
///  3. 重启 Finder 让扩展挂上右键菜单
///  4. 在 Finder 里右键验证
///
/// 状态每 1.5 秒自动刷新一次，用户开完开关回来就能直接看到打勾，不需要手动点"检测"。
/// 判断"扩展是否真的生效"用的是**扩展进程是否存在**（pgrep），
/// 比 pluginkit 查询可靠得多 —— 新版 macOS 已经不允许普通进程查询插件状态了。
final class SetupGuideController: NSObject {

    private weak var app: AppDelegate?
    private var sheet: NSWindow?
    private var statusLabel: NSTextField!

    private var refreshTimer: Timer?
    private var didRestartFinder = false

    /// 步骤角标，按顺序对应上面 4 步（第 1 步固定显示）
    private var badgeForAppLocation: NSTextField!
    private var badgeForEnable: NSTextField!
    private var badgeForRestart: NSTextField!
    private var badgeForVerify: NSTextField!

    init(app: AppDelegate) {
        self.app = app
        super.init()
    }

    // MARK: - 展示 / 关闭

    func present() {
        guard let host = app?.window else { return }

        if let existing = sheet {
            host.makeKeyAndOrderFront(nil)
            existing.makeKey()
            return
        }

        let panel = buildPanel()
        sheet = panel

        // 打开引导时顺手把扩展重新登记一次，提高它出现在设置列表里的概率
        app?.registerExtension()

        host.beginSheet(panel) { [weak self] _ in
            self?.teardown()
        }

        refresh()

        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    @objc private func close() {
        guard let host = app?.window, let panel = sheet else { return }
        host.endSheet(panel)
    }

    private func teardown() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        sheet = nil
    }

    // MARK: - 动作

    @objc private func openSettings() {
        app?.openSystemSettings()
    }

    @objc private func reRegister() {
        app?.registerExtension()
        refresh()
    }

    @objc private func restartFinder() {
        didRestartFinder = true
        app?.restartFinder()
        refresh()
    }

    // MARK: - 实时状态

    private func refresh() {
        guard let app = app else { return }

        let inApplications = Bundle.main.bundlePath.hasPrefix("/Applications/")
        let running = app.isExtensionProcessRunning()
        let state = app.currentExtensionState()

        updateBadge(badgeForAppLocation, done: inApplications)
        updateBadge(badgeForEnable, done: running)
        updateBadge(badgeForRestart, done: didRestartFinder)
        updateBadge(badgeForVerify, done: running)

        if running {
            statusLabel.stringValue = "✅ 扩展已加载并生效 —— 现在去 Finder 里右键任意 .app / .pkg / .dmg，应能看到「🔓 解除安装限制」与「🔍 查看扩展属性」。"
            statusLabel.textColor = .systemGreen
            return
        }

        if !inApplications {
            statusLabel.stringValue = "⚠️ 应用当前运行在 \((Bundle.main.bundlePath as NSString).abbreviatingWithTildeInPath) —— 请先执行 make install 安装到「应用程序」，否则扩展不会被系统登记。"
            statusLabel.textColor = .systemOrange
            return
        }

        switch state {
        case .enabled:
            statusLabel.stringValue = "⚠️ 系统显示扩展已启用，但还没被 Finder 加载 —— 点第 3 步的「重启 Finder」。"
            statusLabel.textColor = .systemOrange
        case .disabled:
            statusLabel.stringValue = "⏳ 等待你在系统设置里开启扩展 —— 点第 2 步的「打开系统设置」；列表里若找不到 MacUnblock，点「重新登记扩展」再回来看看。"
            statusLabel.textColor = .systemOrange
        case .missing:
            statusLabel.stringValue = "❌ 应用包内缺少 Finder 扩展 —— 请重新执行 make install 构建完整应用。"
            statusLabel.textColor = .systemRed
        case .undetectable:
            statusLabel.stringValue = didRestartFinder
                ? "ℹ️ 系统不允许自动检测扩展状态。已完成前两步的话，直接在 Finder 里右键安装包验证即可。"
                : "ℹ️ 系统不允许自动检测扩展状态 —— 按上面 3 步操作后，在 Finder 里右键验证。"
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    private func updateBadge(_ badge: NSTextField?, done: Bool) {
        guard let badge = badge else { return }
        badge.stringValue = done ? "✓" : badge.identifier.map { $0.rawValue } ?? ""
        badge.textColor = done ? .white : .secondaryLabelColor
        badge.layer?.backgroundColor = done
            ? NSColor.systemGreen.cgColor
            : NSColor.quaternaryLabelColor.cgColor
    }

    // MARK: - 界面搭建

    private func buildPanel() -> NSWindow {
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 496),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "引导设置 · 开启 Finder 右键菜单"
        panel.contentView = buildContent()
        return panel
    }

    private func buildContent() -> NSView {
        let root = NSView()

        let title = makeLabel("开启 Finder 右键菜单", font: .systemFont(ofSize: 17, weight: .semibold))
        let subtitle = makeLabel(
            "拖拽和「选择文件…」不需要扩展；这一步只影响 Finder 右键菜单。完成后可以随时关掉这个窗口。",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            wraps: true
        )

        badgeForAppLocation = makeBadge("1")
        badgeForEnable = makeBadge("2")
        badgeForRestart = makeBadge("3")
        badgeForVerify = makeBadge("4")

        let step1 = makeStepRow(
            badge: badgeForAppLocation,
            title: "确认应用在「应用程序」文件夹",
            detail: "Finder 扩展只有被系统发现才可能登记。执行 make install 会自动装到 /Applications。",
            buttons: []
        )

        let step2 = makeStepRow(
            badge: badgeForEnable,
            title: "在系统设置里开启 MacUnblock 扩展",
            detail: "系统设置 → 通用 → 登录项与扩展 → 「扩展 / 文件提供程序」分组里找到 MacUnblock 并打开开关。\n"
                + "（macOS 12 ~ 14 的路径是「隐私与安全性 → 扩展」）",
            buttons: [("打开系统设置", #selector(openSettings)), ("重新登记扩展", #selector(reRegister))]
        )

        let step3 = makeStepRow(
            badge: badgeForRestart,
            title: "重启 Finder，让扩展挂上右键菜单",
            detail: "扩展被开启或重新构建后必须重新加载才会生效。",
            buttons: [("重启 Finder", #selector(restartFinder))]
        )

        let step4 = makeStepRow(
            badge: badgeForVerify,
            title: "在 Finder 里右键安装包验证",
            detail: "随便找一个 .app / .pkg / .dmg，右键应能看到「🔓 解除安装限制」和「🔍 查看扩展属性」。",
            buttons: []
        )

        let steps = NSStackView(views: [step1, step2, step3, step4])
        steps.orientation = .vertical
        steps.alignment = .leading
        steps.spacing = 14
        steps.translatesAutoresizingMaskIntoConstraints = false

        // steps 的宽度由外层约束决定（左右各留 24），把每行拉到同宽，
        // 这样各行右侧的按钮才能对齐到同一条竖线上
        for row in [step1, step2, step3, step4] {
            row.widthAnchor.constraint(equalTo: steps.widthAnchor).isActive = true
        }

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        statusLabel = makeLabel("正在检测…", font: .systemFont(ofSize: 12), color: .secondaryLabelColor, wraps: true)

        let recheckButton = NSButton(title: "重新检测", target: self, action: #selector(recheck))
        recheckButton.bezelStyle = .rounded
        recheckButton.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = NSButton(title: "完成", target: self, action: #selector(close))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow = NSStackView(views: [closeButton, recheckButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(title)
        root.addSubview(subtitle)
        root.addSubview(steps)
        root.addSubview(separator)
        root.addSubview(statusLabel)
        root.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            subtitle.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            steps.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 18),
            steps.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            steps.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            separator.topAnchor.constraint(equalTo: steps.bottomAnchor, constant: 18),
            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            statusLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            buttonRow.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            buttonRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            buttonRow.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
        ])

        return root
    }

    @objc private func recheck() {
        refresh()
    }

    // MARK: - 小控件

    private func makeLabel(
        _ text: String,
        font: NSFont,
        color: NSColor = .labelColor,
        wraps: Bool = false
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        if wraps {
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            // 允许被压缩，否则长文案会把面板顶宽
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    /// 圆形序号角标（完成后变成绿底白勾）
    private func makeBadge(_ number: String) -> NSTextField {
        let badge = NSTextField(labelWithString: number)
        badge.identifier = NSUserInterfaceItemIdentifier(number)
        badge.font = .systemFont(ofSize: 12, weight: .semibold)
        badge.alignment = .center
        badge.textColor = .secondaryLabelColor
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 11
        badge.layer?.masksToBounds = true
        badge.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 22),
            badge.heightAnchor.constraint(equalToConstant: 22),
        ])
        return badge
    }

    private func makeStepRow(
        badge: NSTextField,
        title: String,
        detail: String,
        buttons: [(String, Selector)]
    ) -> NSView {
        let titleLabel = makeLabel(title, font: .systemFont(ofSize: 13, weight: .medium))
        let detailLabel = makeLabel(detail, font: .systemFont(ofSize: 11), color: .secondaryLabelColor, wraps: true)

        let textStack = NSStackView(views: [titleLabel, detailLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let actionStack = NSStackView()
        actionStack.orientation = .horizontal
        actionStack.spacing = 6
        for (title, action) in buttons {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            button.controlSize = .small
            actionStack.addArrangedSubview(button)
        }
        actionStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let row = NSStackView(views: [badge, textStack, actionStack])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        // 文字列吃掉剩余宽度，把 actionStack 顶到最右侧
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        actionStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        return row
    }
}
