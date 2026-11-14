//  ActionExecutor.swift
//  Carries out actions on the Mac: reminders, calendar events, markdown notes
//  (+ Apple Notes), Mail drafts (never sent), links, apps, Shortcuts and
//  AppleScript. Every method returns an `ActionResult` instead of throwing so
//  callers (the Inbox, auto-approval and the agent's tools) can show the message.

import Foundation
import AppKit

// MARK: - Process helper

private struct ProcessOutcome: Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
    var timedOut: Bool
    var launchError: String?

    var succeeded: Bool { launchError == nil && !timedOut && exitCode == 0 }

    /// The most useful one-line-ish description of a failure.
    var failureText: String {
        if let launchError { return launchError }
        let err = stderr.trimmed
        if !err.isEmpty { return err.clipped(1_500) }
        let out = stdout.trimmed
        if !out.isEmpty { return out.clipped(1_500) }
        return "exit status \(exitCode)"
    }
}

/// Collects pipe output from a reader thread.
private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func set(_ newValue: Data) {
        lock.lock()
        data = newValue
        lock.unlock()
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

private enum ProcessRunner {
    /// Runs an executable off the calling thread, capturing stdout/stderr, killing it after `timeout`.
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval) async -> ProcessOutcome {
        await withCheckedContinuation { (continuation: CheckedContinuation<ProcessOutcome, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: ProcessRunner.runBlocking(path, arguments, timeout: timeout))
            }
        }
    }

    private static func runBlocking(_ path: String, _ arguments: [String], timeout: TimeInterval) -> ProcessOutcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do {
            try process.run()
        } catch {
            return ProcessOutcome(exitCode: -1, stdout: "", stderr: "", timedOut: false,
                                  launchError: "Could not launch \(path): \(error.localizedDescription)")
        }

        // Drain both pipes concurrently so a chatty process never blocks on a full pipe.
        let outBuffer = OutputBuffer()
        let errBuffer = OutputBuffer()
        let readers = DispatchGroup()
        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            outBuffer.set(outHandle.readDataToEndOfFile())
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            errBuffer.set(errHandle.readDataToEndOfFile())
            readers.leave()
        }

        var timedOut = false
        if exited.wait(timeout: .now() + max(timeout, 1)) == .timedOut {
            timedOut = true
            Log.error("ActionExecutor: \(path) exceeded \(Int(timeout)) s; terminating it.")
            process.terminate()
            if exited.wait(timeout: .now() + 3) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = exited.wait(timeout: .now() + 2)
            }
        }
        _ = readers.wait(timeout: .now() + 5)

        let status: Int32 = process.isRunning ? -1 : process.terminationStatus
        return ProcessOutcome(exitCode: status,
                              stdout: String(decoding: outBuffer.value, as: UTF8.self),
                              stderr: String(decoding: errBuffer.value, as: UTF8.self),
                              timedOut: timedOut,
                              launchError: nil)
    }
}

// MARK: - Text helpers

private enum ScriptText {
    /// A quoted AppleScript string literal: backslashes and double quotes escaped, CR/LF normalised.
    static func literal(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let escaped = normalized
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    static func html(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Value for a double-quoted YAML scalar.
    static func yaml(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        return "\"" + singleLine.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// File-name-safe version of a title (no path separators or control characters, ≤ 80 characters).
    static func fileName(_ title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters).union(.newlines)
        var scalars = String.UnicodeScalarView()
        for scalar in title.unicodeScalars {
            scalars.append(forbidden.contains(scalar) ? " " : scalar)
        }
        let replaced = String(scalars)
        let collapsed = replaced.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        var name = collapsed.trimmed
        while name.hasPrefix(".") { name.removeFirst() }
        name = String(name.prefix(80)).trimmed
        return name.isEmpty ? "Note" : name
    }
}

private struct MailRecipient {
    var name: String?
    var address: String
}

// MARK: - Executor

final class ActionExecutor: @unchecked Sendable {
    private let db: Database
    private let calendar: CalendarService
    private let lock = NSLock()
    private var storedAgentRunner: (@Sendable (_ task: String) async -> String)?

    private static let defaultEventMinutes: Double = 30
    private static let shortcutTimeout: TimeInterval = 120
    private static let appleScriptTimeout: TimeInterval = 60

    init(db: Database, calendar: CalendarService) {
        self.db = db
        self.calendar = calendar
    }

    /// Runs the agent for .agentTask actions (set by AppModel). Returns the agent's final text.
    var agentRunner: (@Sendable (_ task: String) async -> String)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedAgentRunner
        }
        set {
            lock.lock()
            storedAgentRunner = newValue
            lock.unlock()
        }
    }

    // MARK: Stored actions

    /// Marks running → done/failed, stores result + executedAt, posts .actions.
    func execute(_ action: ProposedAction) async -> ActionResult {
        var record = action
        record.status = .running
        record.result = nil
        db.upsertAction(record)
        EarshotEvents.post(.actions)
        Log.info("ActionExecutor: running \(action.kind.rawValue) \"\(action.title.clipped(60))\" (\(action.id))")

        let result = await perform(action)

        var finished = db.action(id: action.id) ?? record
        finished.status = result.success ? .done : .failed
        finished.result = result.message
        finished.executedAt = Date()
        db.upsertAction(finished)
        EarshotEvents.post(.actions)
        if result.success {
            Log.info("ActionExecutor: \(action.kind.rawValue) \(action.id) done: \(result.message.clipped(200))")
        } else {
            Log.error("ActionExecutor: \(action.kind.rawValue) \(action.id) failed: \(result.message.clipped(300))")
        }
        return result
    }

    private func perform(_ action: ProposedAction) async -> ActionResult {
        let payload = action.payload
        switch action.kind {
        case .reminder:
            return await createReminder(title: action.title, notes: payload.notes, dueISO: payload.dueISO)

        case .calendarEvent:
            guard let start = payload.startISO?.nilIfEmpty ?? payload.dueISO?.nilIfEmpty else {
                return failure("This event has no start time.")
            }
            return await createEvent(title: action.title, startISO: start, endISO: payload.endISO,
                                     location: payload.location, notes: payload.notes)

        case .note:
            let body = payload.body?.nilIfEmpty ?? payload.notes?.nilIfEmpty ?? action.rationale
            return await createNote(title: action.title, body: body)

        case .emailDraft:
            return await draftEmail(to: payload.recipient,
                                    subject: payload.subject?.nilIfEmpty ?? action.title,
                                    body: payload.body ?? payload.notes ?? "")

        case .openURL:
            guard let url = payload.url?.nilIfEmpty else { return failure("There is no link to open.") }
            return await openURL(url)

        case .openApp:
            return await openApp(payload.appName?.nilIfEmpty ?? action.title)

        case .shortcut:
            return await runShortcut(name: payload.shortcutName?.nilIfEmpty ?? action.title, input: payload.input)

        case .appleScript:
            guard let script = payload.script?.nilIfEmpty else { return failure("There is no AppleScript to run.") }
            return await runAppleScript(script)

        case .agentTask:
            guard let runner = agentRunner else { return failure("Agent unavailable") }
            let task = payload.task?.nilIfEmpty ?? action.title
            let text = await runner(task)
            return ActionResult(success: true, message: text.nilIfEmpty ?? "The agent finished the task.")
        }
    }

    // MARK: Reminders & calendar

    func createReminder(title: String, notes: String?, dueISO: String?) async -> ActionResult {
        let cleanTitle = title.trimmed
        guard !cleanTitle.isEmpty else { return failure("A reminder needs a title.") }

        var due: Date?
        var dateOnly = false
        if let raw = dueISO?.nilIfEmpty {
            guard let parsed = DateParsing.parse(raw) else {
                return failure("Couldn't understand the due date \"\(raw)\". Use ISO 8601, e.g. 2026-11-14T15:00:00-08:00, or 2026-11-14 for a whole day.")
            }
            due = parsed
            dateOnly = DateParsing.isDateOnly(raw)
        }

        guard await ensureReminderAccess() else {
            return failure("Earshot doesn't have access to Reminders. Allow it in System Settings → Privacy & Security → Reminders.")
        }
        do {
            _ = try calendar.createReminder(title: cleanTitle, notes: notes, due: due, dateOnly: dateOnly)
            var message = "Created reminder \"\(cleanTitle)\""
            if let due {
                message += dateOnly ? ", due \(ActionExecutor.dayText(due))" : ", due \(due.shortText)"
            }
            return success(message + ".")
        } catch {
            return failure("Couldn't create the reminder: \(error.localizedDescription)")
        }
    }

    func createEvent(title: String, startISO: String, endISO: String?, location: String?, notes: String?) async -> ActionResult {
        let cleanTitle = title.trimmed
        guard !cleanTitle.isEmpty else { return failure("An event needs a title.") }
        guard let start = DateParsing.parse(startISO) else {
            return failure("Couldn't understand the start time \"\(startISO)\". Use ISO 8601, e.g. 2026-11-14T15:00:00-08:00, or 2026-11-14 for an all-day event.")
        }
        let allDay = DateParsing.isDateOnly(startISO)

        var end: Date
        if let rawEnd = endISO?.nilIfEmpty {
            guard let parsedEnd = DateParsing.parse(rawEnd) else {
                return failure("Couldn't understand the end time \"\(rawEnd)\". Use ISO 8601, e.g. 2026-11-14T16:00:00-08:00.")
            }
            end = parsedEnd
        } else {
            end = allDay ? start : start.addingTimeInterval(ActionExecutor.defaultEventMinutes * 60)
        }
        if allDay {
            if end < start { end = start }
        } else if end <= start {
            end = start.addingTimeInterval(ActionExecutor.defaultEventMinutes * 60)
        }

        guard await ensureEventAccess() else {
            return failure("Earshot doesn't have access to your calendars. Allow it in System Settings → Privacy & Security → Calendars.")
        }
        do {
            _ = try calendar.createEvent(title: cleanTitle, start: start, end: end,
                                         location: location?.nilIfEmpty, notes: notes?.nilIfEmpty, allDay: allDay)
            let when: String
            if allDay {
                let firstDay = ActionExecutor.dayText(start)
                let lastDay = ActionExecutor.dayText(end)
                when = firstDay == lastDay ? "all day on \(firstDay)" : "all day, \(firstDay) – \(lastDay)"
            } else {
                let sameDay = Calendar.current.isDate(start, inSameDayAs: end)
                when = "\(start.shortText) – \(sameDay ? end.timeText : end.shortText)"
            }
            var message = "Added \"\(cleanTitle)\" to your calendar, \(when)"
            if let place = location?.nilIfEmpty { message += " at \(place)" }
            return success(message + ".")
        } catch {
            return failure("Couldn't create the event: \(error.localizedDescription)")
        }
    }

    private func ensureReminderAccess() async -> Bool {
        if calendar.hasReminderAccess { return true }
        _ = await calendar.requestAccess()
        return calendar.hasReminderAccess
    }

    private func ensureEventAccess() async -> Bool {
        if calendar.hasEventAccess { return true }
        _ = await calendar.requestAccess()
        return calendar.hasEventAccess
    }

    // MARK: Notes

    /// Markdown file in settings.notesFolderPath (+ Apple Notes when enabled).
    func createNote(title: String, body: String) async -> ActionResult {
        let settings = SettingsStore.current
        let cleanTitle = title.trimmed.isEmpty ? "Untitled note" : title.trimmed
        let configured = settings.notesFolderPath.trimmed
        let folderPath = configured.isEmpty ? AppSettings().notesFolderPath : configured
        let folder = URL(fileURLWithPath: (folderPath as NSString).expandingTildeInPath, isDirectory: true)
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return failure("Couldn't create the notes folder \(folder.path): \(error.localizedDescription)")
        }

        let now = Date()
        let stampFormatter = DateFormatter()
        stampFormatter.locale = Locale(identifier: "en_US_POSIX")
        stampFormatter.timeZone = TimeZone.current
        stampFormatter.dateFormat = "yyyy-MM-dd HHmm"
        let baseName = "\(stampFormatter.string(from: now)) \(ScriptText.fileName(cleanTitle))"
        var fileURL = folder.appendingPathComponent(baseName + ".md")
        var counter = 2
        while fileManager.fileExists(atPath: fileURL.path) {
            fileURL = folder.appendingPathComponent("\(baseName) \(counter).md")
            counter += 1
        }

        let text = body.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let content = """
        ---
        title: \(ScriptText.yaml(cleanTitle))
        created: \(DateParsing.isoLocal(now))
        source: Earshot
        ---

        # \(cleanTitle.replacingOccurrences(of: "\n", with: " "))

        \(text)

        """
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            return failure("Couldn't save the note to \(fileURL.path): \(error.localizedDescription)")
        }
        Log.info("ActionExecutor: saved note \(fileURL.lastPathComponent)")

        var message = "Saved note \"\(cleanTitle)\" to \(fileURL.path)."
        if settings.alsoCreateAppleNotes {
            let apple = await createAppleNote(title: cleanTitle, body: text)
            message += apple.success ? " Also added it to Apple Notes." : " Apple Notes copy failed: \(apple.message)"
        }
        return success(message)
    }

    private func createAppleNote(title: String, body: String) async -> ActionResult {
        var html = "<div><h1>\(ScriptText.html(title))</h1></div>"
        for line in body.components(separatedBy: "\n") {
            html += line.trimmed.isEmpty ? "<div><br></div>" : "<div>\(ScriptText.html(line))</div>"
        }
        let properties = "{name:\(ScriptText.literal(title)), body:\(ScriptText.literal(html))}"
        // Try the most specific form first; older Notes versions lack some of these terms.
        let variants = [
            "tell application \"Notes\" to make new note at default folder of default account with properties \(properties)",
            "tell application \"Notes\" to make new note at folder \"Notes\" with properties \(properties)",
            "tell application \"Notes\" to make new note with properties \(properties)",
        ]
        var lastError = "unknown error"
        for script in variants {
            let outcome = await runOsascript(script, timeout: ActionExecutor.appleScriptTimeout)
            if outcome.succeeded { return success("Added to Apple Notes.") }
            lastError = ActionExecutor.describeAppleScriptFailure(outcome)
            if outcome.timedOut || lastError.contains("-1743") { break }
        }
        Log.error("ActionExecutor: Apple Notes failed: \(lastError)")
        return failure(lastError)
    }

    // MARK: Mail

    /// Mail.app visible draft, never sends.
    func draftEmail(to: String?, subject: String, body: String) async -> ActionResult {
        let parsed = ActionExecutor.parseRecipients(to)
        let cleanSubject = subject.trimmed
        var lines = [
            "tell application \"Mail\"",
            "set newMessage to make new outgoing message with properties {subject:\(ScriptText.literal(cleanSubject)), content:\(ScriptText.literal(body)), visible:true}",
        ]
        if !parsed.recipients.isEmpty {
            lines.append("tell newMessage")
            for recipient in parsed.recipients {
                var fields = "address:\(ScriptText.literal(recipient.address))"
                if let name = recipient.name { fields = "name:\(ScriptText.literal(name)), " + fields }
                lines.append("make new to recipient at end of to recipients with properties {\(fields)}")
            }
            lines.append("end tell")
        }
        lines.append("activate")
        lines.append("end tell")

        let outcome = await runOsascript(lines.joined(separator: "\n"), timeout: ActionExecutor.appleScriptTimeout)
        guard outcome.succeeded else {
            return failure("Couldn't create the Mail draft: \(ActionExecutor.describeAppleScriptFailure(outcome))")
        }
        var message = "Opened a draft \"\(cleanSubject.isEmpty ? "(no subject)" : cleanSubject)\" in Mail"
        if !parsed.recipients.isEmpty {
            message += " to \(parsed.recipients.map { $0.address }.joined(separator: ", "))"
        }
        message += ". It has not been sent."
        if !parsed.unresolved.isEmpty {
            message += " Add the address for \(parsed.unresolved.joined(separator: ", ")) before sending."
        }
        return success(message)
    }

    /// "Sam <sam@example.com>, ana@example.com; Bob" → two recipients, "Bob" unresolved.
    private static func parseRecipients(_ raw: String?) -> (recipients: [MailRecipient], unresolved: [String]) {
        guard let raw = raw?.nilIfEmpty else { return ([], []) }
        var recipients: [MailRecipient] = []
        var unresolved: [String] = []
        for part in raw.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" }) {
            let token = String(part).trimmed
            guard !token.isEmpty else { continue }
            if let openIndex = token.firstIndex(of: "<"), let closeIndex = token.lastIndex(of: ">"), openIndex < closeIndex {
                let address = String(token[token.index(after: openIndex)..<closeIndex]).trimmed
                let name = String(token[..<openIndex]).trimmingCharacters(in: CharacterSet(charactersIn: "\"' ").union(.whitespaces))
                if isEmailAddress(address) {
                    recipients.append(MailRecipient(name: name.isEmpty ? nil : name, address: address))
                } else {
                    unresolved.append(token)
                }
            } else if isEmailAddress(token) {
                recipients.append(MailRecipient(name: nil, address: token))
            } else {
                unresolved.append(token)
            }
        }
        return (recipients, unresolved)
    }

    private static func isEmailAddress(_ text: String) -> Bool {
        guard let at = text.firstIndex(of: "@"), at != text.startIndex else { return false }
        let domain = text[text.index(after: at)...]
        return !domain.isEmpty && domain.contains(".") && !text.contains(" ") && text.filter({ $0 == "@" }).count == 1
    }

    // MARK: Links & apps

    func openURL(_ urlString: String) async -> ActionResult {
        let raw = urlString.trimmed
        guard !raw.isEmpty else { return failure("There is no link to open.") }
        guard let url = ActionExecutor.makeURL(raw) else {
            return failure("\"\(raw.clipped(200))\" is not a valid link.")
        }
        if url.isFileURL {
            let path = url.path
            let blockedExtensions: Set<String> = ["app", "command", "sh", "tool", "pkg", "mpkg", "scpt", "scptd",
                                                  "applescript", "workflow", "terminal", "shortcut", "dmg"]
            if blockedExtensions.contains(url.pathExtension.lowercased()) ||
                (FileManager.default.isExecutableFile(atPath: path) && !ActionExecutor.isDirectory(path)) {
                return failure("Refusing to open \(url.lastPathComponent) as a link: it can run code. Use open_app for applications.")
            }
            guard FileManager.default.fileExists(atPath: path) else {
                return failure("There is no file at \(path).")
            }
        }
        let opened = await MainActor.run { NSWorkspace.shared.open(url) }
        return opened ? success("Opened \(url.absoluteString.clipped(200)).")
                      : failure("macOS couldn't open \(url.absoluteString.clipped(200)).")
    }

    private static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Adds https:// to bare domains ("example.com", "localhost:3000") and percent-encodes spaces.
    private static func makeURL(_ raw: String) -> URL? {
        var text = raw
        if text.hasPrefix("~/") || text.hasPrefix("/") {
            return URL(fileURLWithPath: (text as NSString).expandingTildeInPath)
        }
        let schemePattern = "^[A-Za-z][A-Za-z0-9+.-]*:"
        let hasScheme = text.range(of: schemePattern, options: .regularExpression) != nil
        let looksLikeHostPort = text.range(of: "^[A-Za-z0-9.-]+:[0-9]+(/|$)", options: .regularExpression) != nil
        if !hasScheme || looksLikeHostPort {
            text = "https://" + text
        }
        if let url = URL(string: text), url.scheme != nil { return url }
        let allowed = CharacterSet.urlQueryAllowed.union(.urlPathAllowed).union(CharacterSet(charactersIn: "#%"))
        if let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed),
           let url = URL(string: encoded), url.scheme != nil {
            return url
        }
        return nil
    }

    func openApp(_ name: String) async -> ActionResult {
        let query = name.trimmed
        guard !query.isEmpty else { return failure("Which app should I open?") }
        guard let appURL = await locateApplication(query) else {
            return failure("Couldn't find an app named \"\(query)\" in /Applications, /System/Applications or ~/Applications.")
        }
        do {
            let launchedName = try await ActionExecutor.launchApplication(at: appURL)
            return success("Opened \(launchedName).")
        } catch {
            return failure("Couldn't open \(appURL.deletingPathExtension().lastPathComponent): \(error.localizedDescription)")
        }
    }

    @MainActor
    private static func launchApplication(at url: URL) async throws -> String {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        return app.localizedName ?? url.deletingPathExtension().lastPathComponent
    }

    /// Bundle identifier, absolute path, or "<name>.app" in the usual application folders.
    private func locateApplication(_ query: String) async -> URL? {
        let fileManager = FileManager.default
        if query.hasPrefix("/") || query.hasPrefix("~") {
            let path = (query as NSString).expandingTildeInPath
            if path.lowercased().hasSuffix(".app"), fileManager.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        if query.contains("."), !query.contains(" "), !query.lowercased().hasSuffix(".app") {
            let bundleID = query
            if let url = await MainActor.run(body: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }) {
                return url
            }
        }

        var base = query
        if base.lowercased().hasSuffix(".app") { base = String(base.dropLast(4)) }
        let wanted = base.trimmed.lowercased()
        guard !wanted.isEmpty else { return nil }

        let home = fileManager.homeDirectoryForCurrentUser.path
        let roots = ["/Applications", "/System/Applications", "/Applications/Utilities",
                     "/System/Applications/Utilities", home + "/Applications",
                     "/System/Library/CoreServices", "/System/Library/CoreServices/Applications"]

        var folders: [String] = []
        for root in roots where !folders.contains(root) {
            folders.append(root)
        }
        // One level of sub-folders (e.g. "/Applications/Microsoft Office").
        for root in ["/Applications", home + "/Applications"] {
            guard let items = try? fileManager.contentsOfDirectory(atPath: root) else { continue }
            for item in items where !item.lowercased().hasSuffix(".app") && !item.hasPrefix(".") {
                let path = (root as NSString).appendingPathComponent(item)
                if ActionExecutor.isDirectory(path), !folders.contains(path) { folders.append(path) }
            }
        }

        var looseMatches: [String] = []
        for folder in folders {
            guard let items = try? fileManager.contentsOfDirectory(atPath: folder) else { continue }
            for item in items where item.lowercased().hasSuffix(".app") {
                let appName = String(item.dropLast(4)).lowercased()
                let path = (folder as NSString).appendingPathComponent(item)
                if appName == wanted { return URL(fileURLWithPath: path) }
                if appName.contains(wanted) { looseMatches.append(path) }
            }
        }
        // "Chrome" → "Google Chrome": prefer the shortest app name containing the query.
        if let best = looseMatches.min(by: { $0.count < $1.count }) {
            return URL(fileURLWithPath: best)
        }
        return nil
    }

    // MARK: Shortcuts

    /// /usr/bin/shortcuts run
    func runShortcut(name: String, input: String?) async -> ActionResult {
        let shortcut = name.trimmed
        guard !shortcut.isEmpty else { return failure("Which Shortcut should I run?") }
        let fileManager = FileManager.default
        let token = UUID().uuidString
        let directory = AppPaths.temporaryDirectory
        let outputURL = directory.appendingPathComponent("shortcut-\(token)-output")
        var inputURL: URL?
        defer {
            try? fileManager.removeItem(at: outputURL)
            if let inputURL { try? fileManager.removeItem(at: inputURL) }
        }

        var arguments = ["run", shortcut]
        if let input, !input.isEmpty {
            let url = directory.appendingPathComponent("shortcut-\(token)-input.txt")
            do {
                try input.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                return failure("Couldn't prepare the Shortcut input: \(error.localizedDescription)")
            }
            inputURL = url
            arguments += ["--input-path", url.path]
        }
        arguments += ["--output-path", outputURL.path]

        let outcome = await ProcessRunner.run("/usr/bin/shortcuts", arguments, timeout: ActionExecutor.shortcutTimeout)
        if outcome.timedOut {
            return failure("The Shortcut \"\(shortcut)\" didn't finish within \(Int(ActionExecutor.shortcutTimeout)) seconds and was stopped.")
        }
        guard outcome.succeeded else {
            return failure("The Shortcut \"\(shortcut)\" failed: \(outcome.failureText)")
        }

        var output = ""
        if let data = try? Data(contentsOf: outputURL), !data.isEmpty {
            if let text = String(data: data, encoding: .utf8) {
                output = text.trimmed
            } else {
                output = "(\(data.count) bytes of non-text output)"
            }
        }
        if output.isEmpty { output = outcome.stdout.trimmed }
        var message = "Ran the Shortcut \"\(shortcut)\"."
        if !output.isEmpty { message += "\nOutput:\n\(output.clipped(4_000))" }
        return success(message)
    }

    func listShortcuts() async -> [String] {
        let outcome = await ProcessRunner.run("/usr/bin/shortcuts", ["list"], timeout: 30)
        guard outcome.succeeded else {
            Log.error("ActionExecutor: shortcuts list failed: \(outcome.failureText)")
            return []
        }
        return outcome.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
    }

    // MARK: AppleScript

    /// /usr/bin/osascript
    func runAppleScript(_ source: String) async -> ActionResult {
        guard source.nilIfEmpty != nil else { return failure("The AppleScript is empty.") }
        let outcome = await runOsascript(source, timeout: ActionExecutor.appleScriptTimeout)
        guard outcome.succeeded else {
            return failure("AppleScript failed: \(ActionExecutor.describeAppleScriptFailure(outcome))")
        }
        let output = outcome.stdout.trimmed
        return success(output.isEmpty ? "AppleScript ran successfully." : "AppleScript result:\n\(output.clipped(4_000))")
    }

    /// Passes the script to osascript one `-e` line at a time (osascript joins them with newlines).
    private func runOsascript(_ script: String, timeout: TimeInterval) async -> ProcessOutcome {
        let normalized = script.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var arguments: [String] = []
        for line in normalized.components(separatedBy: "\n") {
            arguments.append("-e")
            arguments.append(line)
        }
        return await ProcessRunner.run("/usr/bin/osascript", arguments, timeout: timeout)
    }

    private static func describeAppleScriptFailure(_ outcome: ProcessOutcome) -> String {
        if outcome.timedOut {
            return "it didn't finish within \(Int(appleScriptTimeout)) seconds and was stopped."
        }
        let text = outcome.failureText
        if text.contains("-1743") {
            return text + " — allow Earshot to control that app in System Settings → Privacy & Security → Automation."
        }
        if text.contains("-1728") || text.contains("-1708") {
            return text + " — the app doesn't support that command or object."
        }
        return text
    }

    // MARK: Results

    private func success(_ message: String) -> ActionResult {
        ActionResult(success: true, message: message)
    }

    private func failure(_ message: String) -> ActionResult {
        ActionResult(success: false, message: message)
    }

    private static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
