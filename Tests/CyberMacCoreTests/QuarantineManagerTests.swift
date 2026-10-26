import Darwin
import Foundation
import XCTest
@testable import CyberMacCore

final class QuarantineManagerTests: XCTestCase {
    func testNativeAttributeLookupFindsNestedFilesWithoutFollowingSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("compiler")
        try Data("test".utf8).write(to: file)
        let manager = QuarantineManager()
        XCTAssertFalse(manager.hasQuarantineAttribute(file))
        let value = Array("0081;test;CyberMac;".utf8)
        let result = value.withUnsafeBytes { bytes in
            setxattr(file.path, "com.apple.quarantine", bytes.baseAddress, bytes.count, 0, 0)
        }
        XCTAssertEqual(result, 0)
        XCTAssertTrue(manager.hasQuarantineAttribute(file))
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertFalse(manager.hasQuarantineAttribute(link))
        XCTAssertEqual(manager.quarantinedPaths(under: root).map { $0.resolvingSymlinksInPath() }, [file.resolvingSymlinksInPath()])
        XCTAssertFalse(manager.hasQuarantineAttribute(root.appendingPathComponent("missing")))
    }
}
