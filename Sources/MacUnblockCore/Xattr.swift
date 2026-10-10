import Foundation
import Darwin

// MARK: - 扩展属性（xattr）工具
//
// 为什么不用 /usr/bin/xattr 子进程，也不走 App Sandbox：
//
// 1) App Sandbox 的配置文件里硬编码了
//      (deny file-write-xattr (xattr "com.apple.quarantine"))
//    （见 /System/Library/Sandbox/Profiles/application.sb）
//    也就是说任何沙箱进程都不可能移除隔离属性，不是 entitlements 能解决的问题，
//    所以主应用必须运行在沙箱之外。
//
// 2) 通过 Process 启动 /usr/bin/xattr 时，父进程从拖拽/选择文件拿到的
//    sandbox extension 不会继承给子进程，子进程访问该文件会直接 EPERM。
//    旧的报错 "xattr: [Errno 1] Operation not permitted" 就来自这里。
//
// 因此这里直接调用 libsystem 的 listxattr / removexattr，在当前进程内完成。

public enum Xattr {
    /// errno 93 == ENOATTR（属性不存在）
    private static let enoattr: Int32 = 93

    /// 这些属性需要保留：删掉会丢失 Finder 图标 / 标签 / 资源分支等信息
    public static let preserved: Set<String> = ["com.apple.ResourceFork", "com.apple.FinderInfo"]

    public static func list(_ path: String) -> [String] {
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
            return L.t("err.permission", text)
        case EROFS:
            return L.t("err.readonly")
        case ENOTSUP:
            return L.t("err.notsup")
        default:
            return L.t("err.generic", text, Int(code))
        }
    }
}
