import CyberMacCore
import Foundation
import XCTest

final class PathSafetyShellQuotingTests: XCTestCase {
    func testDoubleQuoting_escapesBackslash() {
        XCTAssertEqual(
            PathSafety.shellDoubleQuoted("a\\b"),
            "\"a\\\\b\""
        )
    }

    func testDoubleQuoting_escapesDoubleQuote() {
        XCTAssertEqual(
            PathSafety.shellDoubleQuoted("a\"b"),
            "\"a\\\"b\""
        )
    }

    func testDoubleQuoting_escapesDollar() {
        XCTAssertEqual(
            PathSafety.shellDoubleQuoted("a$HOME"),
            "\"a\\$HOME\""
        )
    }

    func testDoubleQuoting_escapesBacktick() {
        XCTAssertEqual(
            PathSafety.shellDoubleQuoted("a`whoami`"),
            "\"a\\`whoami\\`\""
        )
    }

    func testDoubleQuoting_passesThroughBangLiterally() {
        // `!` is not expanded inside double quotes in non-interactive bash/zsh.
        // The double-quoted command strings CyberMac shows users are intended for
        // pasting into a shell, where it remains literal in non-history contexts.
        XCTAssertEqual(
            PathSafety.shellDoubleQuoted("a!b"),
            "\"a!b\""
        )
    }

    func testDoubleQuoting_passesThroughNewlineLiterally() {
        XCTAssertEqual(
            PathSafety.shellDoubleQuoted("a\nb"),
            "\"a\nb\""
        )
    }

    func testDoubleQuoting_handlesUnicode() {
        XCTAssertEqual(
            PathSafety.shellDoubleQuoted("/Users/猫/Library/Cyberpunk 2077"),
            "\"/Users/猫/Library/Cyberpunk 2077\""
        )
    }

    func testDoubleQuoting_escapesCombinedHostileSequence() {
        let input = "$(rm -rf ~)`whoami`\"escape\""
        let quoted = PathSafety.shellDoubleQuoted(input)
        XCTAssertEqual(
            quoted,
            "\"\\$(rm -rf ~)\\`whoami\\`\\\"escape\\\"\""
        )
    }

    func testSingleQuoting_escapesEmbeddedSingleQuote() {
        XCTAssertEqual(
            PathSafety.shellQuoted("it's a path"),
            "'it'\\''s a path'"
        )
    }

    func testSingleQuoting_wrapsPlainString() {
        XCTAssertEqual(
            PathSafety.shellQuoted("/Users/example/Cyberpunk 2077.app"),
            "'/Users/example/Cyberpunk 2077.app'"
        )
    }
}
