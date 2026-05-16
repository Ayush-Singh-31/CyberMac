import Foundation

enum ArchiveCatalogParser {
    static func validateCatalogDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw CyberMacError.unsafePath("Archive catalog directory must not be a symlink: \(url.path)")
        }
        guard values.isDirectory == true else {
            throw CyberMacError.notFound("Archive catalog directory does not exist: \(url.path)")
        }
    }

    static func catalogFiles(under catalogDirectory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: catalogDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                continue
            }
            files.append(url.standardizedFileURL)
        }

        return try files.sorted {
            try PathSafety.relativePath(of: $0, in: catalogDirectory) < PathSafety.relativePath(of: $1, in: catalogDirectory)
        }
    }

    static func readCatalogText(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CyberMacError.invalidInput("Archive catalog file is not UTF-8 text: \(url.path)")
        }
        return text
    }

    static func normalizedExtensionFilter(_ rawExtension: String?) throws -> String? {
        guard let rawExtension else { return nil }
        let value = rawExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        guard !value.isEmpty else {
            throw CyberMacError.invalidInput("Archive catalog extension filter cannot be empty.")
        }
        guard !value.contains("/"), !value.contains("\\") else {
            throw CyberMacError.invalidInput("Archive catalog extension filter must not contain path separators: \(rawExtension)")
        }
        return value
    }

    static func assetPathCandidates(in line: String) -> [String] {
        line.components(separatedBy: .whitespacesAndNewlines)
            .compactMap(cleanedToken)
            .filter(isAssetPath)
    }

    static func assetExtension(_ assetPath: String) -> String? {
        let normalized = assetPath.replacingOccurrences(of: "\\", with: "/")
        guard let fileName = normalized.split(separator: "/").last else { return nil }
        guard let dotIndex = fileName.lastIndex(of: "."),
              dotIndex != fileName.startIndex,
              dotIndex != fileName.index(before: fileName.endIndex)
        else {
            return nil
        }
        return String(fileName[fileName.index(after: dotIndex)...]).lowercased()
    }

    static func inferArchivePath(sourceCatalogFile: String, text: String) -> String? {
        let headerText = text
            .split(whereSeparator: \.isNewline)
            .prefix(20)
            .joined(separator: "\n")
        let explicitCandidates = officialArchivePathCandidates(in: "\(sourceCatalogFile)\n\(headerText)")
        if explicitCandidates.count == 1 {
            return explicitCandidates.first
        }

        return inferArchivePathFromCatalogFileName(sourceCatalogFile)
    }

    private static func cleanedToken(_ rawToken: String) -> String? {
        let trimCharacters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\"'`[](){}<>:,;"))
        var token = rawToken.trimmingCharacters(in: trimCharacters)
        if let delimiterIndex = token.lastIndex(where: { $0 == "=" || $0 == ":" }) {
            let value = String(token[token.index(after: delimiterIndex)...])
                .trimmingCharacters(in: trimCharacters)
            if value.contains("/") || value.contains("\\") {
                token = value
            }
        }
        return token.isEmpty ? nil : token
    }

    private static func isAssetPath(_ token: String) -> Bool {
        let normalized = token.replacingOccurrences(of: "\\", with: "/")
        guard normalized.contains("/") else { return false }
        guard !normalized.hasPrefix("/") else { return false }
        guard !normalized.split(separator: "/").contains("..") else { return false }
        guard !normalized.lowercased().hasPrefix("data/archive/") else { return false }
        guard let assetExtension = assetExtension(token), assetExtension != "archive" else { return false }
        return true
    }

    private static func officialArchivePathCandidates(in text: String) -> Set<String> {
        let pattern = #"Data[/_\\-]archive[/_\\-]Mac[/_\\-](content|ep1)[/_\\-]([A-Za-z0-9._-]+?\.archive)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var candidates = Set<String>()
        for match in regex.matches(in: text, options: [], range: range) {
            guard match.numberOfRanges == 3,
                  let directoryRange = Range(match.range(at: 1), in: text),
                  let fileRange = Range(match.range(at: 2), in: text)
            else {
                continue
            }
            let directory = String(text[directoryRange]).lowercased()
            let fileName = String(text[fileRange])
            let relativePath = "Data/archive/Mac/\(directory)/\(fileName)"
            if let validated = try? OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(relativePath) {
                candidates.insert(validated)
            }
        }
        return candidates
    }

    private static func inferArchivePathFromCatalogFileName(_ sourceCatalogFile: String) -> String? {
        let pattern = #"([A-Za-z0-9._-]+?\.archive)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(sourceCatalogFile.startIndex..<sourceCatalogFile.endIndex, in: sourceCatalogFile)
        let matches = regex.matches(in: sourceCatalogFile, options: [], range: range)
        let names = Set(matches.compactMap { match -> String? in
            guard let matchRange = Range(match.range(at: 1), in: sourceCatalogFile) else { return nil }
            return String(sourceCatalogFile[matchRange])
        })
        guard names.count == 1, let archiveName = names.first else {
            return nil
        }

        let lowerSource = sourceCatalogFile.lowercased()
        let lowerArchiveName = archiveName.lowercased()
        let directory: String?
        if lowerSource.contains("/ep1/")
            || lowerSource.contains("_ep1_")
            || lowerArchiveName.hasPrefix("ep1_") {
            directory = "ep1"
        } else if lowerSource.contains("/content/")
                    || lowerSource.contains("_content_")
                    || lowerArchiveName.hasPrefix("basegame_")
                    || lowerArchiveName.hasPrefix("memoryresident_") {
            directory = "content"
        } else {
            directory = nil
        }

        guard let directory else { return nil }
        return try? OfficialArchiveBackupManager.validateOfficialRelativeArchivePath(
            "Data/archive/Mac/\(directory)/\(archiveName)"
        )
    }
}
