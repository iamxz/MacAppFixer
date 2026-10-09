import Cocoa
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        createMainWindow()
    }

    func createMainWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MacUnblock"
        window.contentView = createContentView()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createContentView() -> NSView {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // App icon
        let iconImageView = NSImageView()
        iconImageView.image = NSImage(
            systemSymbolName: "shield.lefthalf.filled",
            accessibilityDescription: "App Icon"
        )
        iconImageView.contentTintColor = .controlAccentColor
        iconImageView.symbolConfiguration = .init(pointSize: 48, weight: .regular)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        // Title label
        let titleLabel = NSTextField(labelWithString: "MacUnblock")
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Description label
        let descLabel = NSTextField(labelWithString: "右键解除 macOS 应用安装限制\n移除 com.apple.quarantine 隔离属性")
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status label
        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.identifier = NSUserInterfaceItemIdentifier("statusLabel")

        // Enable button
        let enableButton = NSButton(title: "启用 Finder 扩展", target: self, action: #selector(enableExtension))
        enableButton.bezelStyle = .rounded
        enableButton.controlSize = .large
        enableButton.translatesAutoresizingMaskIntoConstraints = false
        enableButton.keyEquivalent = ""
        enableButton.identifier = NSUserInterfaceItemIdentifier("enableButton")

        // Open button (open System Settings Extensions)
        let openButton = NSButton(title: "打开系统设置 → 扩展", target: self, action: #selector(openSystemSettings))
        openButton.bezelStyle = .rounded
        openButton.controlSize = .large
        openButton.translatesAutoresizingMaskIntoConstraints = false

        // Instructions label
        let instructionsLabel = NSTextField(labelWithString: "")
        instructionsLabel.stringValue = """
        使用方法：
        1. 点击「启用 Finder 扩展」按钮
        2. 在系统设置中允许扩展运行
        3. 在 Finder 中右键 .app 文件
        4. 选择「解除安装限制」即可
        """
        instructionsLabel.font = .systemFont(ofSize: 12)
        instructionsLabel.textColor = .tertiaryLabelColor
        instructionsLabel.alignment = .left
        instructionsLabel.isEditable = false
        instructionsLabel.isBordered = false
        instructionsLabel.drawsBackground = false
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(enableButton)
        containerView.addSubview(openButton)
        containerView.addSubview(instructionsLabel)

        // Layout
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            enableButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            enableButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            openButton.topAnchor.constraint(equalTo: enableButton.bottomAnchor, constant: 8),
            openButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            instructionsLabel.topAnchor.constraint(equalTo: openButton.bottomAnchor, constant: 20),
            instructionsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            instructionsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
        ])

        // Check extension status
        updateStatusLabel(statusLabel)

        return containerView
    }

    func updateStatusLabel(_ label: NSTextField) {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let extId = bundleId + ".FinderSync"
        let installed = checkExtensionInstalled(extId)
        let enabled = checkExtensionEnabled(extId)

        if installed && enabled {
            label.stringValue = "✅ Finder 扩展已启用，请在 Finder 中右键 .app 文件使用"
            label.textColor = .systemGreen
        } else if installed {
            label.stringValue = "⚠️ 扩展已安装但未启用，请在系统设置中开启"
            label.textColor = .systemOrange
        } else {
            label.stringValue = "❌ 扩展未安装，请重新安装应用"
            label.textColor = .systemRed
        }
    }

    func checkExtensionInstalled(_ bundleId: String) -> Bool {
        // Check via pluginkit
        let task = Process()
        task.launchPath = "/usr/bin/pluginkit"
        task.arguments = ["-m", "-p", "com.apple.FinderSync"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains(bundleId)
        } catch {
            return false
        }
    }

    func checkExtensionEnabled(_ bundleId: String) -> Bool {
        // On macOS 13+, use SMAppService
        if #available(macOS 13.0, *) {
            // For Finder Sync extensions, check via pluginkit -v
            let task = Process()
            task.launchPath = "/usr/bin/pluginkit"
            task.arguments = ["-m", "-v"]
            let pipe = Pipe()
            task.standardOutput = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                // If the plugin shows a '+' it's enabled
                for line in output.components(separatedBy: "\n") {
                    if line.contains(bundleId) && line.contains("+") {
                        return true
                    }
                }
                return false
            } catch {
                return false
            }
        }
        return false
    }

    @objc func enableExtension() {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let extId = bundleId + ".FinderSync"
        let task = Process()
        task.launchPath = "/usr/bin/pluginkit"
        task.arguments = ["-e", "use", "-i", extId]
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // ignore
        }

        // Open System Settings to Extensions
        openSystemSettings()

        // Update status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let contentView = self?.window.contentView,
                  let statusLabel = contentView.viewWithIdentifier(NSUserInterfaceItemIdentifier("statusLabel")) as? NSTextField else {
                return
            }
            self?.updateStatusLabel(statusLabel)
        }
    }

    @objc func openSystemSettings() {
        if #available(macOS 13.0, *) {
            let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
            NSWorkspace.shared.open(url)
        } else {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.extensions")!
            NSWorkspace.shared.open(url)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
