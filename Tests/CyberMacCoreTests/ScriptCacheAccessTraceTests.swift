import Foundation
import XCTest
@testable import CyberMacCore

final class ScriptCacheAccessTraceTests: XCTestCase {
    func testChunkedTraceUsesSenderIdentityAndDoesNotRetainUnrelatedPaths() {
        var filter = ScriptCacheTraceFilter(controlName: "cm-trace-control")
        let source = """
        12:00:00 stat64 /private/tmp/cm-trace-control 0.0001 stat.123
        12:00:01 open /Applications/Cyberpunk2077.app/Contents/Data/r6/cache/final.redscripts 0.0001 mds.456
        12:00:02 open r6/cache/final.redscripts 0.0001 Cyberpunk2077.789
        12:00:03 open /private/something-personal 0.0001 Finder.123

        """
        let bytes = Data(source.utf8)
        for start in stride(from: 0, to: bytes.count, by: 7) {
            filter.consume(bytes.subdata(in: start..<min(start + 7, bytes.count)))
        }
        filter.finish()
        XCTAssertTrue(filter.evidence.controlObserved)
        XCTAssertEqual(filter.evidence.gameEventCount, 1)
        XCTAssertEqual(filter.evidence.scriptRows.count, 1)
        XCTAssertEqual(filter.evidence.gameContextRows, filter.evidence.scriptRows)
        XCTAssertTrue(filter.evidence.scriptRows[0].contains("Cyberpunk2077.789"))
        XCTAssertFalse(filter.evidence.incomplete)
        XCTAssertFalse(filter.evidence.scriptRows.joined().contains("something-personal"))
        XCTAssertFalse(filter.evidence.gameContextRows.joined().contains("something-personal"))
    }

    func testUnnamedGameAccessesRemainAvailableWithoutImplyingScriptAccess() {
        var filter = ScriptCacheTraceFilter(controlName: "control")
        filter.consume(Data("""
        12:00:01 open F=12 0.0001 Cyberpunk2077.789
        12:00:02 RdData F=12 B=0x1000 0.0001 Cyberpunk2077.789
        12:00:03 mmap F=12 A=0x123000 0.0001 Cyberpunk2077.789
        12:00:04 mmap F=90 A=0x123000 0.0001 Finder.789

        """.utf8))
        filter.finish()
        XCTAssertEqual(filter.evidence.gameContextRows.count, 3)
        XCTAssertEqual(filter.evidence.gameEventCount, 3)
        XCTAssertTrue(filter.evidence.scriptRows.isEmpty)
        XCTAssertFalse(filter.evidence.gameContextRowsTruncated)
        XCTAssertFalse(filter.evidence.incomplete)
    }

    func testContextSamplingDoesNotStopSeparateScriptRetention() {
        var filter = ScriptCacheTraceFilter(controlName: "control")
        for _ in 0..<2100 { filter.consume(Data("mmap F=12 Cyberpunk2077.123\n".utf8)) }
        filter.consume(Data("open r6/cache/final.redscripts Cyberpunk2077.123\n".utf8))
        XCTAssertEqual(filter.evidence.gameEventCount, 2101)
        XCTAssertEqual(filter.evidence.gameContextRows.count, 2048)
        XCTAssertTrue(filter.evidence.gameContextRowsTruncated)
        XCTAssertEqual(filter.evidence.scriptRows.count, 1)
        // Sampling is explicit and distinct from actual tracer loss.
        XCTAssertFalse(filter.evidence.incomplete)
    }

    func testRetainedRowsAreBoundedAndExhaustionIsExplicit() {
        var filter = ScriptCacheTraceFilter(controlName: "control")
        for _ in 0..<300 { filter.consume(Data("open r6/cache/final.redscripts Cyberpunk2077.123\n".utf8)) }
        XCTAssertEqual(filter.evidence.scriptRows.count, 256)
        XCTAssertEqual(filter.evidence.gameEventCount, 300)
        XCTAssertTrue(filter.evidence.incomplete)
    }

    func testLongPartialAndLostLinesCannotBecomeCompleteEvidence() {
        var filter = ScriptCacheTraceFilter(controlName: "control")
        filter.consume(Data(repeating: 65, count: 70_000))
        filter.consume(Data("\nopen final.redscripts Cyberpunk2077.123\n".utf8))
        XCTAssertTrue(filter.evidence.incomplete)
        XCTAssertEqual(filter.evidence.scriptRows.count, 1)
        var partial = ScriptCacheTraceFilter(controlName: "control")
        partial.consume(Data("open final.redscripts Cyberpunk2077.123".utf8)); partial.finish()
        XCTAssertTrue(partial.evidence.incomplete)
        XCTAssertEqual(partial.evidence.scriptRows.count, 0)
        var lost = ScriptCacheTraceFilter(controlName: "control")
        lost.consume(Data("lost events: kernel buffer overflow\n".utf8))
        XCTAssertTrue(lost.evidence.incomplete)
    }

    func testPipeSourceDrainsControlAndBoundsErrorOutput() throws {
        let source = "import sys; print('stat64 /tmp/cm-control stat.123'); print('open r6/cache/final.redscripts Cyberpunk2077.456'); sys.stderr.write('E' * 20000)"
        let trace = ScriptCacheAccessTrace(controlName: "cm-control",
            command: (URL(fileURLWithPath: "/usr/bin/python3"), ["-c", source]))
        try trace.start()
        let deadline = Date().addingTimeInterval(5)
        while trace.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        let result = trace.stop()
        XCTAssertTrue(result.controlObserved)
        XCTAssertEqual(result.scriptRows.count, 1)
        XCTAssertEqual(result.diagnostics.utf8.count, 16 * 1024)
        XCTAssertTrue(result.incomplete)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNotNil(result.startedAt)
        XCTAssertNotNil(result.endedAt)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(result.endedAt), try XCTUnwrap(result.startedAt))
    }

    func testStalledSourceIsTerminatedWithinDeadline() throws {
        let trace = ScriptCacheAccessTrace(controlName: "control", command: (URL(fileURLWithPath: "/usr/bin/python3"),
            ["-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('control', flush=True); time.sleep(60)"]))
        try trace.start()
        let readyDeadline = Date().addingTimeInterval(5)
        while !trace.snapshot().controlObserved && Date() < readyDeadline { Thread.sleep(forTimeInterval: 0.01) }
        XCTAssertTrue(trace.snapshot().controlObserved)
        let began = Date(); let result = trace.stop()
        XCTAssertLessThan(Date().timeIntervalSince(began), 5)
        XCTAssertFalse(trace.isRunning)
        XCTAssertEqual(result.exitCode, SIGKILL)
    }
}
