import XCTest
import Darwin
@testable import MacAppFixerCore

final class UnblockerTests: XCTestCase {

    // MARK: - 支持的格式判定

    func testSupportedExtensionsAreCaseInsensitive() {
        XCTAssertTrue(Unblocker.isSupported(URL(fileURLWithPath: "/tmp/Foo.app")))
        XCTAssertTrue(Unblocker.isSupported(URL(fileURLWithPath: "/tmp/Foo.PKG")))
        XCTAssertTrue(Unblocker.isSupported(URL(fileURLWithPath: "/tmp/Bar.dmg")))
        XCTAssertFalse(Unblocker.isSupported(URL(fileURLWithPath: "/tmp/notes.txt")))
        XCTAssertFalse(Unblocker.isSupported(URL(fileURLWithPath: "/tmp/archive.zip")))
    }

    func testSupportedExtensionsSet() {
        XCTAssertEqual(
            Unblocker.supportedExtensions,
            ["app", "pkg", "mpkg", "dmg", "ipa", "appex"]
        )
    }

    // MARK: - xattr 列出 / 移除

    func testListAndRemoveCustomAttribute() throws {
        let file = try makeTempFile(named: "sample.bin")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let name = "com.macappfixer.test"
        try setUserXattr(name, value: "1", at: file.path)

        XCTAssertTrue(Xattr.list(file.path).contains(name), "设置后应能列出该属性")

        let result = Unblocker.unblock(file)
        XCTAssertTrue(result.ok)
        XCTAssertFalse(Xattr.list(file.path).contains(name), "解除后该属性应被移除")
    }

    func testRecursiveUnblockRemovesNestedAttributes() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let nestedDir = root.appendingPathComponent("Payload/Nested")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        let nestedFile = nestedDir.appendingPathComponent("inner.bin")
        FileManager.default.createFile(atPath: nestedFile.path, contents: Data("hi".utf8))

        let name = "com.macappfixer.test"
        try setUserXattr(name, value: "1", at: root.appendingPathComponent("Payload").path)
        try setUserXattr(name, value: "1", at: nestedFile.path)

        let result = Unblocker.unblock(root)
        XCTAssertTrue(result.ok)
        XCTAssertFalse(Xattr.list(root.appendingPathComponent("Payload").path).contains(name))
        XCTAssertFalse(Xattr.list(nestedFile.path).contains(name), "嵌套文件上的属性也应被递归清除")
    }

    func testUnblockingCleanFileReportsNothingToDo() throws {
        let file = try makeTempFile(named: "clean.bin")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let result = Unblocker.unblock(file)
        XCTAssertTrue(result.ok)
    }

    func testMissingFileReportsNotFound() {
        let missing = URL(fileURLWithPath: "/tmp/macappfixer-does-not-exist-\(UUID().uuidString).app")
        let result = Unblocker.unblock(missing)
        XCTAssertFalse(result.ok)
    }

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("macappfixer-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeTempFile(named name: String) throws -> URL {
        let dir = try makeTempDirectory()
        let file = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: file.path, contents: Data("hi".utf8))
        return file
    }

    /// 在临时文件系统不支持用户扩展属性时跳过，而不是让测试失败。
    private func setUserXattr(_ name: String, value: String, at path: String) throws {
        let bytes = Array(value.utf8)
        let rc = name.withCString { namePtr in
            bytes.withUnsafeBufferPointer { buf in
                setxattr(path, namePtr, buf.baseAddress, buf.count, 0, 0)
            }
        }
        if rc != 0 {
            throw XCTSkip("当前文件系统不支持用户扩展属性（errno \(errno)）")
        }
    }
}
