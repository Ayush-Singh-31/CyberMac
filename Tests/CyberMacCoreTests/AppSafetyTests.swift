import Foundation
import XCTest

final class AppSafetyTests: XCTestCase {
    func testCyberMacAppDoesNotExecuteManualPrivilegedCommands() throws {
        let appDirectory = try packageRoot().appendingPathComponent("CyberMacApp", isDirectory: true)
        let swiftFiles = try swiftSourceFiles(in: appDirectory)
        let forbiddenPatterns = [
            #"Process\s*\("#,
            #"Process\s*\(\s*\)"#,
            #"/bin/(sh|zsh|bash)"#,
            #"\b(sh|zsh|bash)\s+-c\b"#,
            #"\bsudo\s+cp\b"#,
            #"osascript"#,
            #"with administrator privileges"#,
            #"AuthorizationExecuteWithPrivileges"#,
            #"NSAppleScript"#,
            #"do shell script"#
        ]
        var violations: [String] = []

        for file in swiftFiles {
            let contents = try String(contentsOf: file, encoding: .utf8)
            let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, lineValue) in lines.enumerated() {
                let line = String(lineValue)
                for pattern in forbiddenPatterns where line.range(of: pattern, options: .regularExpression) != nil {
                    violations.append("\(file.lastPathComponent):\(index + 1): forbidden activation execution pattern `\(pattern)`")
                }
                if line.contains("sudo"), !isAllowedSudoDisplayLine(file: file, line: line) {
                    violations.append("\(file.lastPathComponent):\(index + 1): `sudo` is only allowed as display-only ManualCommand text")
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    private func isAllowedSudoDisplayLine(file: URL, line: String) -> Bool {
        guard file.lastPathComponent == "AppState.swift" else { return false }
        return line.contains("sudoCommand")
            || line.contains("sudoCommands")
            || line.contains("printed sudo copy command")
    }

    private func swiftSourceFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw NSError(domain: "AppSafetyTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not enumerate \(directory.path)"])
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private func packageRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(domain: "AppSafetyTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find Package.swift from \(#filePath)"])
    }
}
