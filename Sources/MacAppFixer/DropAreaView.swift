import Cocoa
import MacAppFixerCore

// MARK: - Drop Area View

/// 拖拽区域：既接收文件拖入，也响应点击（打开文件选择器）。
class DropAreaView: NSView {
    weak var appDelegate: AppDelegate?
    private var isDragOver = false

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

    // MARK: - 拖拽

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = extractURLs(from: sender)
        let hasSupported = urls.contains(where: Unblocker.isSupported)

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
        let supported = extractURLs(from: sender).filter(Unblocker.isSupported)

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
