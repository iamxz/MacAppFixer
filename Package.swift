// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacUnblock",
    platforms: [.macOS(.v12)],
    targets: [
        // 逻辑层：不依赖 AppKit，纯 xattr / 文件处理，可被单元测试直接覆盖
        .target(name: "MacUnblockCore"),
        // 应用层：AppKit 界面与入口，依赖逻辑层
        .executableTarget(
            name: "MacUnblock",
            dependencies: ["MacUnblockCore"]
        ),
        .testTarget(
            name: "MacUnblockCoreTests",
            dependencies: ["MacUnblockCore"]
        ),
    ]
)
