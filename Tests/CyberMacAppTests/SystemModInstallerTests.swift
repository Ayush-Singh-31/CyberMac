import XCTest
@testable import CyberMacApp

final class SystemModInstallerTests: XCTestCase {
    func testNativeAuthorizationCancellationIsSeparateFromPermissionDenial() {
        let cancelled = NSError(domain: NSOSStatusErrorDomain, code: -60006)
        XCTAssertTrue(SystemModInstaller.isCancellation(cancelled))
        XCTAssertTrue(SystemModInstaller.isCancellation(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)))
        XCTAssertTrue(SystemModInstaller.isCancellation(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                                                               userInfo: [NSUnderlyingErrorKey: cancelled])))
        XCTAssertFalse(SystemModInstaller.isCancellation(NSError(domain: NSPOSIXErrorDomain, code: 1)))
    }
    func testBlockedReplacementDoesNotRepeatPermissionAdviceWhenAlreadyEnabled() {
        let detail = "mv: rename payload to final.redscripts: Operation not permitted"
        let message = SystemModInstaller.failureMessage(detail, filesUnchanged: true)
        XCTAssertTrue(message.contains("Privacy & Security → App Management"))
        XCTAssertTrue(message.contains("already enabled"))
        XCTAssertTrue(message.contains("leave it enabled"))
        XCTAssertTrue(message.contains("game files are unchanged"))
        XCTAssertTrue(message.contains(detail))
        XCTAssertTrue(SystemModInstaller.needsAppManagement(message))
    }
    func testOrdinaryFailureKeepsRecoveryInstructionsWithoutPermissionClaim() {
        let message = SystemModInstaller.failureMessage("A planned file changed", filesUnchanged: false)
        XCTAssertTrue(message.contains("recovery plan"))
        XCTAssertFalse(message.contains("files are unchanged"))
        XCTAssertFalse(SystemModInstaller.needsAppManagement(message))
    }
}
