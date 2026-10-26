import XCTest
@testable import CyberMacCore

final class RedscriptCompatibilityTests: XCTestCase {
    func testPatch25RejectsOldCompilerAndAcceptsSupportedReleases() {
        XCTAssertNotNil(RedscriptCompatibility.setupIssue(runtimeVersion: "0.5.31", gameVersion: "2.5"))
        XCTAssertNil(RedscriptCompatibility.setupIssue(runtimeVersion: "0.5.32", gameVersion: "2.5.0"))
        XCTAssertNil(RedscriptCompatibility.setupIssue(runtimeVersion: "0.5.33", gameVersion: "2.5"))
        XCTAssertNil(RedscriptCompatibility.setupIssue(runtimeVersion: "0.5.31", gameVersion: "2.4"))
    }

    func testUnknownOrPreviewVersionNeedsVerifiedRelease() {
        for version in [nil, "0.5.32-preview.1", "unknown"] as [String?] {
            XCTAssertNotNil(RedscriptCompatibility.setupIssue(runtimeVersion: version, gameVersion: "2.5"))
        }
        XCTAssertEqual(RuntimeArchiveImporter.versionString(from: "redscript-v0.5.32-macos"), "0.5.32")
    }
}
