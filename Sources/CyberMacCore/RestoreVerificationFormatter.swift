import Foundation

public enum RestoreVerificationFormatter {
    public static func format(_ result: RestoreVerificationResult) -> String {
        switch result.status {
        case .verified:
            return "Restore verified."
        case .hashMismatch(let expected, let actual, let target):
            return """
            Restore verify failed.

            Bundle target:
              \(target)

            Expected backup SHA-256:
              \(expected)

            Actual bundle SHA-256:
              \(actual)

            Likely cause:
              The printed sudo restore command has not been run yet, or a different file was copied.

            Run:
              \(result.restoreCommand)

            Then:
              \(result.verifyCommand)
            """
        case .expectedAbsentButFileExists(let target, let actualHash):
            return """
            Restore verify failed.

            Expected bundle target:
              \(target)

            Expected prior state:
              absent

            Actual state:
              file exists

            Actual bundle SHA-256:
              \(actualHash)

            Likely cause:
              The printed sudo rm command has not been run.

            Run:
              \(result.restoreCommand)

            Then:
              \(result.verifyCommand)
            """
        case .expectedPresentButFileMissing(let target):
            return """
            Restore verify failed.

            Expected bundle target:
              \(target)

            Actual state:
              file missing

            Expected prior state:
              present

            Likely cause:
              The restore copy failed or the bundle target was deleted.

            Run:
              \(result.restoreCommand)

            Then:
              \(result.verifyCommand)
            """
        case .staleBackup(let expected, let actual):
            return """
            Restore verify failed.

            Expected game fingerprint:
              \(expected)

            Actual game fingerprint:
              \(actual)

            Likely cause:
              This backup belongs to a different Cyberpunk app build.
            """
        }
    }
}
