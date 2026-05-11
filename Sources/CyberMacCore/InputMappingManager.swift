import Foundation

public struct InputMappingExtractor: Sendable {
    public init() {}

    public func extract(from url: URL, modID: String) throws -> ExtractedInputMapping {
        let source = Self.removingXMLComments(from: try String(contentsOf: url, encoding: .utf8))
        let contextBody = try Self.contextBody(named: "UIToggles", in: source)
        let actions = Self.matches(pattern: #"<action\b[^>]*/>"#, in: contextBody)
            .map(\.text)
        let holds = Self.matches(pattern: #"<hold\b[^>]*/>"#, in: source)
            .map(\.text)
        let acceptedEvents = Self.matches(pattern: #"<acceptedEvents\b[^>]*>.*?</acceptedEvents>"#, in: source)
            .map(\.text)
        let mappings = Self.matches(pattern: #"<mapping\b[^>]*>.*?</mapping>"#, in: source)
            .map(\.text)

        let actionNames = actions.compactMap { Self.attribute("name", in: $0) }
        let mappingNames = mappings.compactMap { Self.attribute("name", in: $0) }

        guard !actions.isEmpty, !actionNames.isEmpty else {
            throw CyberMacError.invalidInput("Input mapping XML has no UIToggles action entries: \(url.path)")
        }
        guard !mappings.isEmpty, !mappingNames.isEmpty else {
            throw CyberMacError.invalidInput("Input mapping XML has no key mapping entries: \(url.path)")
        }

        return ExtractedInputMapping(
            modID: modID,
            sourcePath: url.path,
            actionNames: Self.uniquePreservingOrder(actionNames),
            mappingNames: Self.uniquePreservingOrder(mappingNames),
            actionMappingsXML: actions.joined(separator: "\n"),
            holdTimeoutsXML: holds.joined(separator: "\n"),
            acceptedEventsXML: acceptedEvents.joined(separator: "\n"),
            keyMappingsXML: mappings.joined(separator: "\n")
        )
    }

    private static func contextBody(named name: String, in source: String) throws -> String {
        guard let open = firstContextOpenRange(named: name, in: source) else {
            throw CyberMacError.invalidInput("Input mapping XML does not contain <context name=\"\(name)\">")
        }
        guard let close = firstClosingContextRange(after: open.upperBound, in: source) else {
            throw CyberMacError.invalidInput("Input mapping XML context \(name) has no closing </context>")
        }
        return String(source[open.upperBound..<close.lowerBound])
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"\b"# + escaped + #"\s*=\s*(['"])(.*?)\1"#
        guard let match = matches(pattern: pattern, in: tag).first else { return nil }
        return match.captures.last
    }

    fileprivate static func firstContextOpenRange(named name: String, in text: String) -> Range<String.Index>? {
        matches(pattern: #"<context\b[^>]*>"#, in: text).first { match in
            !isInsideXMLComment(match.range, in: text) && attribute("name", in: match.text) == name
        }?.range
    }

    fileprivate static func firstClosingContextRange(after index: String.Index, in text: String) -> Range<String.Index>? {
        let suffix = String(text[index...])
        for match in matches(pattern: #"</context\s*>"#, in: suffix) {
            guard let lower = text.index(index, offsetBy: suffix.distance(from: suffix.startIndex, to: match.range.lowerBound), limitedBy: text.endIndex),
                  let upper = text.index(index, offsetBy: suffix.distance(from: suffix.startIndex, to: match.range.upperBound), limitedBy: text.endIndex) else {
                continue
            }
            let range = lower..<upper
            if !isInsideXMLComment(range, in: text) {
                return range
            }
        }
        return nil
    }

    fileprivate static func firstRange(pattern: String, in text: String) -> Range<String.Index>? {
        matches(pattern: pattern, in: text).first?.range
    }

    fileprivate static func lastRange(pattern: String, in text: String) -> Range<String.Index>? {
        matches(pattern: pattern, in: text).last?.range
    }

    fileprivate static func matches(pattern: String, in text: String) -> [(range: Range<String.Index>, text: String, captures: [String])] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let captures = (1..<match.numberOfRanges).compactMap { index -> String? in
                let captureRange = match.range(at: index)
                guard captureRange.location != NSNotFound,
                      let swiftRange = Range(captureRange, in: text) else {
                    return nil
                }
                return String(text[swiftRange])
            }
            return (range, String(text[range]), captures)
        }
    }

    private static func removingXMLComments(from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"<!--.*?-->"#, options: [.dotMatchesLineSeparators]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static func isInsideXMLComment(_ range: Range<String.Index>, in text: String) -> Bool {
        let prefixRange = text.startIndex..<range.lowerBound
        guard let open = text.range(of: "<!--", options: .backwards, range: prefixRange) else {
            return false
        }
        guard let close = text.range(of: "-->", options: .backwards, range: prefixRange) else {
            return true
        }
        return open.lowerBound > close.lowerBound
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

public struct InputMappingManager: Sendable {
    private let home: CyberMacHomeManager
    private let manifestStore: ManifestStore
    private let stateStore: StateStore
    private let backupManager: InputConfigBackupManager
    private let extractor: InputMappingExtractor

    public init(home: CyberMacHomeManager) {
        self.home = home
        self.manifestStore = ManifestStore(home: home)
        self.stateStore = StateStore(home: home)
        self.backupManager = InputConfigBackupManager(home: home)
        self.extractor = InputMappingExtractor()
    }

    public func inputContextsTarget(gameInstall: GameInstall) -> URL {
        let macURL = gameInstall.dataURL.appendingPathComponent("r6/config/inputContexts_mac.xml")
        if FileManager.default.fileExists(atPath: macURL.path) {
            return macURL
        }
        return gameInstall.dataURL.appendingPathComponent("r6/config/inputContexts.xml")
    }

    public func inputUserMappingsTarget(gameInstall: GameInstall) -> URL {
        gameInstall.dataURL.appendingPathComponent("r6/config/inputUserMappings.xml")
    }

    public func status(gameInstall: GameInstall?) throws -> InputPatchStatus {
        try home.bootstrap()
        let state = stateStore.load()
        let requiredMods = try enabledInputMappingMods()
        let targetContexts = gameInstall.map { inputContextsTarget(gameInstall: $0).path }
        let targetMappings = gameInstall.map { inputUserMappingsTarget(gameInstall: $0).path }
        let nextStep: String
        if requiredMods.isEmpty {
            nextStep = "No enabled mods require input mapping."
        } else if state.pendingInputPatch != nil {
            nextStep = "Run the manual input patch copy commands, then verify input patch."
        } else if Set(state.activeInputPatchModIDs) == Set(requiredMods.map(\.id)) {
            nextStep = "Input patch is active."
        } else {
            nextStep = "Prepare input patch."
        }
        return InputPatchStatus(
            requiredMods: requiredMods,
            pendingInputPatch: state.pendingInputPatch,
            activeInputPatchModIDs: state.activeInputPatchModIDs,
            activeInputTargetHashes: state.activeInputTargetHashes,
            targetInputContextsPath: targetContexts,
            targetInputUserMappingsPath: targetMappings,
            nextStep: nextStep
        )
    }

    public func preparePatch(gameInstall: GameInstall, modIDs: [String]? = nil) throws -> InputPatchPrepareResult {
        try home.bootstrap()
        let mods = try selectedInputMappingMods(modIDs: modIDs)
        guard !mods.isEmpty else {
            throw CyberMacError.invalidInput("No enabled input mapping mods require a patch.")
        }

        let contextTarget = inputContextsTarget(gameInstall: gameInstall)
        let userMappingsTarget = inputUserMappingsTarget(gameInstall: gameInstall)
        guard FileManager.default.fileExists(atPath: contextTarget.path) else {
            throw CyberMacError.notFound("Input contexts target is missing: \(contextTarget.path)")
        }
        guard FileManager.default.fileExists(atPath: userMappingsTarget.path) else {
            throw CyberMacError.notFound("Input user mappings target is missing: \(userMappingsTarget.path)")
        }

        var extracted: [ExtractedInputMapping] = []
        for mod in mods {
            guard !mod.inputMappingFiles.isEmpty else {
                throw CyberMacError.invalidInput("Mod \(mod.id) requires input mapping but has no installed input XML records.")
            }
            for record in mod.inputMappingFiles {
                let url = URL(fileURLWithPath: record.installedPath)
                try PathSafety.validateContainedPath(url, in: home.overlayInputURL.appendingPathComponent(mod.id, isDirectory: true))
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw CyberMacError.notFound("Installed input mapping XML is missing: \(url.path)")
                }
                extracted.append(try extractor.extract(from: url, modID: mod.id))
            }
        }

        var patchedContexts = try String(contentsOf: contextTarget, encoding: .utf8)
        var patchedUserMappings = try String(contentsOf: userMappingsTarget, encoding: .utf8)
        let patcher = InputMappingPatcher()
        for mapping in extracted {
            patchedContexts = try patcher.patchInputContexts(patchedContexts, mapping: mapping)
            patchedUserMappings = try patcher.patchInputUserMappings(patchedUserMappings, mapping: mapping)
        }
        try patcher.validatePatchedInputContexts(patchedContexts, mappings: extracted)
        try patcher.validatePatchedInputUserMappings(patchedUserMappings, mappings: extracted)

        let patchID = Self.makePatchID()
        let patchDirectory = home.tmpURL.appendingPathComponent(patchID, isDirectory: true)
        try FileManager.default.createDirectory(at: patchDirectory, withIntermediateDirectories: true)
        let generatedContext = patchDirectory.appendingPathComponent(contextTarget.lastPathComponent)
        let generatedUserMappings = patchDirectory.appendingPathComponent("inputUserMappings.xml")
        try patchedContexts.write(to: generatedContext, atomically: true, encoding: .utf8)
        try patchedUserMappings.write(to: generatedUserMappings, atomically: true, encoding: .utf8)

        let expectedHashes = [
            contextTarget.path: try PathSafety.sha256(url: generatedContext),
            userMappingsTarget.path: try PathSafety.sha256(url: generatedUserMappings)
        ]
        let backup = try backupManager.backup(gameInstall: gameInstall, modIDs: mods.map(\.id))
        let sudoCommands = [
            sudoCopyCommand(source: generatedContext, target: contextTarget),
            sudoCopyCommand(source: generatedUserMappings, target: userMappingsTarget)
        ]
        let result = InputPatchPrepareResult(
            patchID: patchID,
            modIDs: mods.map(\.id).sorted(),
            generatedContextPath: generatedContext.path,
            generatedUserMappingsPath: generatedUserMappings.path,
            backupID: backup.id,
            expectedHashes: expectedHashes,
            sudoCommands: sudoCommands,
            verifyCommand: "swift run cybermac verify-input-patch"
        )
        let reportURL = patchDirectory.appendingPathComponent("patch-report.json")
        try JSONEncoder.cybermac.encode(result).write(to: reportURL, options: [.atomic])

        var state = stateStore.load()
        state.pendingInputPatch = PendingInputPatch(
            id: patchID,
            createdAt: Date(),
            gameAppPath: gameInstall.appURL.path,
            modIDs: result.modIDs,
            targetHashes: expectedHashes,
            generatedFiles: [
                contextTarget.path: generatedContext.path,
                userMappingsTarget.path: generatedUserMappings.path
            ],
            backupID: backup.id,
            sudoCommands: sudoCommands
        )
        try stateStore.save(state)

        for var mod in mods {
            mod.inputPatchState = .prepared
            try manifestStore.save(mod)
        }

        return result
    }

    public func verifyPatch(gameInstall: GameInstall) throws -> InputPatchVerifyResult {
        var state = stateStore.load()
        guard let pending = state.pendingInputPatch else {
            throw CyberMacError.invalidInput("No input patch pending. Prepare input patch first.")
        }

        var actualHashes: [String: String] = [:]
        var mismatches: [String] = []
        for target in pending.targetHashes.keys.sorted() {
            guard let expected = pending.targetHashes[target] else { continue }
            let targetURL = URL(fileURLWithPath: target)
            guard FileManager.default.fileExists(atPath: targetURL.path) else {
                actualHashes[target] = "missing"
                mismatches.append(target)
                continue
            }
            let actual = try PathSafety.sha256(url: targetURL)
            actualHashes[target] = actual
            if actual != expected {
                mismatches.append(target)
            }
        }

        if mismatches.isEmpty {
            state.activeInputPatchModIDs = pending.modIDs
            state.activeInputTargetHashes = pending.targetHashes
            state.pendingInputPatch = nil
            try stateStore.save(state)
            for id in pending.modIDs {
                var manifest = try manifestStore.load(id: id)
                manifest.inputPatchState = .active
                try manifestStore.save(manifest)
            }
        } else {
            for id in pending.modIDs {
                var manifest = try manifestStore.load(id: id)
                manifest.inputPatchState = .failed
                try manifestStore.save(manifest)
            }
        }

        return InputPatchVerifyResult(
            patchID: pending.id,
            matched: mismatches.isEmpty,
            expectedHashes: pending.targetHashes,
            actualHashes: actualHashes,
            mismatches: mismatches
        )
    }

    private func enabledInputMappingMods() throws -> [InstalledModManifest] {
        try manifestStore.list()
            .filter { $0.status == .enabled && $0.requiresInputMappingPatch }
            .sorted { $0.id < $1.id }
    }

    private func selectedInputMappingMods(modIDs: [String]?) throws -> [InstalledModManifest] {
        let enabled = try enabledInputMappingMods()
        guard let modIDs, !modIDs.isEmpty else { return enabled }
        let requested = Set(modIDs)
        let selected = enabled.filter { requested.contains($0.id) }
        let missing = requested.subtracting(selected.map(\.id))
        guard missing.isEmpty else {
            throw CyberMacError.invalidInput("Requested mods are not enabled input-mapping mods: \(missing.sorted().joined(separator: ", "))")
        }
        return selected
    }

    private func sudoCopyCommand(source: URL, target: URL) -> String {
        "sudo cp \(PathSafety.shellDoubleQuoted(source.path)) \(PathSafety.shellDoubleQuoted(target.path))"
    }

    private static func makePatchID(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return "input-patch-\(formatter.string(from: date))"
    }
}

struct InputMappingPatcher: Sendable {
    func patchInputContexts(_ text: String, mapping: ExtractedInputMapping) throws -> String {
        if hasCyberMacMarker(text, modID: mapping.modID) {
            return text
        }
        try refuseUnmarkedNames(in: text, names: mapping.actionNames, attributes: ["name", "action"], modID: mapping.modID)
        var patched = text
        if !mapping.actionMappingsXML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            patched = try insertActionMappings(mapping.actionMappingsXML, modID: mapping.modID, into: patched)
        }
        if !mapping.holdTimeoutsXML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            patched = try insertAfterLast(pattern: #"<hold\b[^>]*/>"#, section: "HoldTimeouts", xml: mapping.holdTimeoutsXML, modID: mapping.modID, into: patched, missingMessage: "inputContexts target has no <hold ... /> insertion point")
        }
        if !mapping.acceptedEventsXML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            patched = try insertAfterLast(pattern: #"</acceptedEvents>"#, section: "AcceptedEvents", xml: mapping.acceptedEventsXML, modID: mapping.modID, into: patched, missingMessage: "inputContexts target has no </acceptedEvents> insertion point")
        }
        return patched
    }

    func patchInputUserMappings(_ text: String, mapping: ExtractedInputMapping) throws -> String {
        if hasCyberMacMarker(text, modID: mapping.modID) {
            return text
        }
        try refuseUnmarkedNames(in: text, names: mapping.mappingNames, attributes: ["name"], modID: mapping.modID)
        return try insertBeforeFinalBindings(section: "KeyMappings", xml: mapping.keyMappingsXML, modID: mapping.modID, into: text)
    }

    func validatePatchedInputContexts(_ text: String, mappings: [ExtractedInputMapping]) throws {
        try validateBindings(text, label: "inputContexts")
        for mapping in mappings where !hasCyberMacMarker(text, modID: mapping.modID) {
            throw CyberMacError.invalidInput("Generated inputContexts patch is missing CyberMac markers for \(mapping.modID)")
        }
    }

    func validatePatchedInputUserMappings(_ text: String, mappings: [ExtractedInputMapping]) throws {
        try validateBindings(text, label: "inputUserMappings")
        for mapping in mappings where !hasCyberMacMarker(text, modID: mapping.modID) {
            throw CyberMacError.invalidInput("Generated inputUserMappings patch is missing CyberMac markers for \(mapping.modID)")
        }
    }

    private func insertActionMappings(_ xml: String, modID: String, into text: String) throws -> String {
        guard let open = InputMappingExtractor.firstContextOpenRange(named: "UIToggles", in: text) else {
            throw CyberMacError.invalidInput("inputContexts target is missing <context name=\"UIToggles\">")
        }
        guard let close = InputMappingExtractor.firstClosingContextRange(after: open.upperBound, in: text) else {
            throw CyberMacError.invalidInput("UIToggles context is missing closing </context>")
        }
        var patched = text
        patched.insert(contentsOf: "\n\(markerBlock(modID: modID, section: "UITogglesActions", xml: xml))\n", at: close.lowerBound)
        return patched
    }

    private func insertAfterLast(pattern: String, section: String, xml: String, modID: String, into text: String, missingMessage: String) throws -> String {
        guard let range = InputMappingExtractor.lastRange(pattern: pattern, in: text) else {
            throw CyberMacError.invalidInput(missingMessage)
        }
        var patched = text
        patched.insert(contentsOf: "\n\(markerBlock(modID: modID, section: section, xml: xml))", at: range.upperBound)
        return patched
    }

    private func insertBeforeFinalBindings(section: String, xml: String, modID: String, into text: String) throws -> String {
        guard let range = InputMappingExtractor.lastRange(pattern: #"</bindings>"#, in: text) else {
            throw CyberMacError.invalidInput("inputUserMappings target is missing closing </bindings>")
        }
        var patched = text
        patched.insert(contentsOf: "\(markerBlock(modID: modID, section: section, xml: xml))\n", at: range.lowerBound)
        return patched
    }

    private func refuseUnmarkedNames(in text: String, names: [String], attributes: [String], modID: String) throws {
        guard !hasCyberMacMarker(text, modID: modID) else { return }
        for name in names {
            for attribute in attributes {
                let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: attribute) + #"\s*=\s*""# + NSRegularExpression.escapedPattern(for: name) + #"""#
                if InputMappingExtractor.firstRange(pattern: pattern, in: text) != nil {
                    throw CyberMacError.unsupported("Existing manual input mappings detected for \(name). Refusing to duplicate unmarked mappings.")
                }
            }
        }
    }

    private func validateBindings(_ text: String, label: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CyberMacError.invalidInput("Generated \(label) patch is empty")
        }
        guard InputMappingExtractor.firstRange(pattern: #"<bindings\b"#, in: text) != nil,
              InputMappingExtractor.lastRange(pattern: #"</bindings>"#, in: text) != nil else {
            throw CyberMacError.invalidInput("Generated \(label) patch is missing root <bindings>")
        }
    }

    private func hasCyberMacMarker(_ text: String, modID: String) -> Bool {
        text.contains("CyberMac BEGIN input modID=\(modID)")
    }

    private func markerBlock(modID: String, section: String, xml: String) -> String {
        let trimmed = xml.trimmingCharacters(in: .whitespacesAndNewlines)
        let indented = trimmed
            .components(separatedBy: .newlines)
            .map { "    \($0)" }
            .joined(separator: "\n")
        return """
        <!-- CyberMac BEGIN input modID=\(modID) section=\(section) -->
        \(indented)
        <!-- CyberMac END input modID=\(modID) section=\(section) -->
        """
    }
}
