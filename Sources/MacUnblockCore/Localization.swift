import Foundation

/// 本地化入口。
///
/// 所有面向用户的文案都从这里取，实际值放在各语言的
/// `*.lproj/Localizable.strings` 里（当前提供 简体中文 / English 两套）。
/// 构建时这些 `.lproj` 会被拷进 `MacUnblock.app/Contents/Resources/`，
/// 运行时 `NSLocalizedString` 从主 bundle 读取；macOS 会按用户在
/// 「系统设置 → 通用 → 语言与地区」里的偏好自动选择最匹配的一套，
/// 无需应用自己判断，也不会写死某一种语言。
///
/// 用法：
///   L.t("button.choose")                       // 无参数
///   L.t("result.multi_ok", count)              // 带参数，按 format 处理
public enum L {
    /// 取本地化字符串；有参数时按 `String(format:)` 处理（占位符用 %@ / %d）。
    public static func t(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return args.isEmpty ? format : String(format: format, arguments: args)
    }
}
