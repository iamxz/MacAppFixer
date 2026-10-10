import Foundation
import Darwin

// MARK: - 解除限制

public struct UnblockResult {
    public let ok: Bool
    public let message: String

    public init(ok: Bool, message: String) {
        self.ok = ok
        self.message = message
    }
}

public enum Unblocker {
    /// 支持的安装包格式（拖拽与文件选择器共用同一份判定）
    public static let supportedExtensions: Set<String> = [
        "app", "pkg", "mpkg", "dmg", "ipa", "appex",
    ]

    /// 是否为本工具支持的安装包
    public static func isSupported(_ url: URL) -> Bool {
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// 递归移除文件（或 bundle）上的限制属性
    public static func unblock(_ fileURL: URL) -> UnblockResult {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            return UnblockResult(ok: false, message: L.t("unblock.notfound"))
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
            return UnblockResult(ok: true, message: L.t("unblock.clean"))
        }

        if failureCount > 0, let code = firstError {
            return UnblockResult(
                ok: true,
                message: L.t("unblock.partial", removed, failureCount, String(cString: strerror(code)))
            )
        }
        return UnblockResult(ok: true, message: L.t("unblock.done", removed))
    }
}
