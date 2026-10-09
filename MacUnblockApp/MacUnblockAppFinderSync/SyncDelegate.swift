import Cocoa
import FinderSync

class SyncDelegate: FIFinderSync {
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

    // MARK: - Menu Items

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Only show context menu when .app files are selected
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        let targetedURL = FIFinderSyncController.default().targetedURL()

        let hasApp = selectedURLs.contains(where: { $0.pathExtension == "app" })
        let targetedIsApp = targetedURL?.pathExtension == "app"

        if !hasApp && !targetedIsApp {
            return nil
        }

        let menu = NSMenu(title: "MacUnblock")
        menu.addItem(withTitle: "🔓 解除安装限制", action: #selector(unblockApp(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "🔍 查看扩展属性", action: #selector(showXattrInfo(_:)), keyEquivalent: "")
        return menu
    }

    // MARK: - Actions

    @IBAction func unblockApp(_ sender: AnyObject?) {
        var appURLs = (FIFinderSyncController.default().selectedItemURLs() ?? []).filter {
            $0.pathExtension == "app"
        }

        if appURLs.isEmpty {
            if let targeted = FIFinderSyncController.default().targetedURL(),
               targeted.pathExtension == "app" {
                appURLs = [targeted]
            }
        }

        if appURLs.isEmpty {
            return
        }

        var successCount = 0
        var failCount = 0
        var messages: [String] = []

        for url in appURLs {
            let result = unblockSingleApp(url)
            if result.success {
                successCount += 1
            } else {
                failCount += 1
            }
            messages.append("\(url.lastPathComponent): \(result.message)")
        }

        let title: String
        let body: String
        if failCount == 0 {
            title = "✅ 解除成功"
            body = appURLs.count == 1
                ? "已移除 \"\(appURLs[0].lastPathComponent)\" 的隔离属性\n现在可以正常打开了。"
                : "已成功解除 \(successCount) 个应用的限制"
        } else if successCount == 0 {
            title = "❌ 解除失败"
            body = messages.joined(separator: "\n")
        } else {
            title = "⚠️ 部分成功"
            body = "成功: \(successCount), 失败: \(failCount)\n" + messages.joined(separator: "\n")
        }

        showAlert(title: title, body: body)
    }

    func unblockSingleApp(_ appURL: URL) -> (success: Bool, message: String) {
        let appPath = appURL.path

        // Remove quarantine attribute (com.apple.quarantine) recursively
        let result = runXattr(args: ["-r", "-d", "com.apple.quarantine", appPath])
        if !result.success {
            return (false, "移除 com.apple.quarantine 失败: \(result.error)")
        }

        // Also try to remove com.apple.provenance if present (may fail due to SIP)
        _ = runXattr(args: ["-r", "-d", "com.apple.provenance", appPath])

        // List remaining xattr and remove all
        let listResult = runXattrCapture(args: [appPath])
        if listResult.success {
            for attr in listResult.output.components(separatedBy: "\n") {
                let trimmed = attr.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                if trimmed == "com.apple.quarantine" || trimmed == "com.apple.provenance" { continue }
                _ = runXattr(args: ["-r", "-d", trimmed, appPath])
            }
        }

        return (true, "OK")
    }

    @IBAction func showXattrInfo(_ sender: AnyObject?) {
        let appURLs = (FIFinderSyncController.default().selectedItemURLs() ?? []).filter {
            $0.pathExtension == "app"
        }

        for url in appURLs {
            let result = runXattrCapture(args: ["-l", url.path])
            let output = result.success ? result.output : "（无法读取扩展属性）"
            showAlert(
                title: "扩展属性 - \(url.lastPathComponent)",
                body: output.isEmpty ? "（无扩展属性）" : output
            )
        }
    }

    // MARK: - Shell Helpers

    func runXattr(args: [String]) -> (success: Bool, error: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = args
        let errPipe = Pipe()
        task.standardError = errPipe
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errOutput = String(data: errData, encoding: .utf8) ?? "unknown error"
                // xattr returns non-zero if attribute doesn't exist, which is OK
                if errOutput.contains("No such xattr") {
                    return (true, "")
                }
                return (false, errOutput)
            }
            return (true, "")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    func runXattrCapture(args: [String]) -> (success: Bool, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (true, output)
        } catch {
            return (false, "")
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
