//  Exporter.swift
//  "Export everything" (feature #74): a shutdown-proof copy of the archive in
//  open formats, readable without Earshot.
//
//  <folder>/Earshot Export yyyy-MM-dd HHmm/
//      README.md                    every file and field explained
//      Transcripts/yyyy-MM-dd.md    one Markdown transcript per day with speech
//      digests/<day>.md             daily digests and weekly reviews
//      insights.json, goals.json, prompts.json, actions.json
//
//  Pure Foundation; reads only through `Database`'s public methods. Runs
//  synchronously on the caller's thread (call it off the main thread).

import Foundation

enum Exporter {
    /// Writes <folder>/Earshot Export <yyyy-MM-dd HHmm>/ with one Markdown transcript per day
    /// (Transcripts/yyyy-MM-dd.md), insights.json, goals.json, prompts.json, actions.json,
    /// digests/*.md and a README.md describing the schema. Returns the export folder.
    static func exportAll(db: Database, to folder: URL) throws -> URL {
        let now = Date()
        let root = try ExportFolder.create(in: folder, now: now)
        do {
            let summary = try ExportWriter(db: db, root: root, now: now).run()
            Log.info("Export: \(summary.transcriptDays) transcript day(s), \(summary.insights) insights, \(summary.goals) goals, \(summary.prompts) prompts, \(summary.actions) actions and \(summary.digests) digests written to \(root.path)")
            return root
        } catch {
            try? FileManager.default.removeItem(at: root)
            Log.error("Export to \(folder.path) failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Private helpers

private struct ExportSummary {
    var transcriptDays = 0
    var firstDay: String?
    var lastDay: String?
    var utterances = 0
    var words = 0
    var insights = 0
    var goals = 0
    var prompts = 0
    var actions = 0
    var digests = 0
}

private enum ExportFolder {
    /// Creates a new, uniquely named export folder inside `parent`.
    static func create(in parent: URL, now: Date) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        let base = "Earshot Export \(formatter.string(from: now))"
        for attempt in 1...100 {
            let name = attempt == 1 ? base : "\(base) (\(attempt))"
            let candidate = parent.appendingPathComponent(name, isDirectory: true)
            if fileManager.fileExists(atPath: candidate.path) { continue }
            try fileManager.createDirectory(at: candidate, withIntermediateDirectories: false)
            return candidate
        }
        throw CocoaError.error(.fileWriteFileExists, userInfo: nil,
                               url: parent.appendingPathComponent(base, isDirectory: true))
    }
}

private struct ExportWriter {
    /// Row limit that means "everything".
    static let unlimited = 10_000_000

    let db: Database
    let root: URL
    let now: Date
    private let keyFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private let titleFormatter: DateFormatter
    private let stampFormatter: DateFormatter
    private let numberFormatter: NumberFormatter

    init(db: Database, root: URL, now: Date) {
        self.db = db
        self.root = root
        self.now = now

        let key = DateFormatter()
        key.locale = Locale(identifier: "en_US_POSIX")
        key.timeZone = TimeZone.current
        key.dateFormat = "yyyy-MM-dd"
        keyFormatter = key

        let time = DateFormatter()
        time.timeZone = TimeZone.current
        time.dateStyle = .none
        time.timeStyle = .short
        timeFormatter = time

        let title = DateFormatter()
        title.timeZone = TimeZone.current
        title.dateStyle = .full
        title.timeStyle = .none
        titleFormatter = title

        let stamp = DateFormatter()
        stamp.timeZone = TimeZone.current
        stamp.dateStyle = .long
        stamp.timeStyle = .short
        stampFormatter = stamp

        let number = NumberFormatter()
        number.numberStyle = .decimal
        numberFormatter = number
    }

    func run() throws -> ExportSummary {
        let fileManager = FileManager.default
        var summary = ExportSummary()

        let transcriptsDirectory = root.appendingPathComponent("Transcripts", isDirectory: true)
        let digestsDirectory = root.appendingPathComponent("digests", isDirectory: true)
        try fileManager.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: digestsDirectory, withIntermediateDirectories: true)

        let digests = db.digests(limit: ExportWriter.unlimited).sorted { $0.day < $1.day }
        let digestDays = Set(digests.map { $0.day })

        try writeTranscripts(into: transcriptsDirectory, digestDays: digestDays, summary: &summary)

        for digest in digests {
            let name = ExportWriter.safeFileName(digest.day) + ".md"
            try writeText(digest.markdown.trimmed + "\n", to: digestsDirectory.appendingPathComponent(name))
        }
        summary.digests = digests.count

        let insights = db.insights(statuses: nil, kinds: nil, since: nil, limit: ExportWriter.unlimited)
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        try writeJSON(insights, named: "insights.json")
        summary.insights = insights.count

        let goals = db.goals(statuses: nil).sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        try writeJSON(goals, named: "goals.json")
        summary.goals = goals.count

        let prompts = db.prompts(since: .distantPast, limit: ExportWriter.unlimited)
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        try writeJSON(prompts, named: "prompts.json")
        summary.prompts = prompts.count

        let actions = db.actions(statuses: nil, limit: ExportWriter.unlimited)
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        try writeJSON(actions, named: "actions.json")
        summary.actions = actions.count

        try writeText(readme(summary), to: root.appendingPathComponent("README.md"))
        return summary
    }

    // MARK: Transcripts

    /// The earliest recorded moment: first segment or first utterance.
    private func earliestRecord() -> Date? {
        let firstSegment = db.segments(from: .distantPast, to: now).first?.startedAt
        let firstUtterance = db.utterances(from: .distantPast, to: now.endOfDay, limit: 1).first?.startedAt
        return [firstSegment, firstUtterance].compactMap { $0 }.min()
    }

    private func writeTranscripts(into directory: URL, digestDays: Set<String>, summary: inout ExportSummary) throws {
        guard let earliest = earliestRecord() else { return }
        let lastDay = now.startOfDay
        var day = earliest.startOfDay
        while day <= lastDay {
            let next = day.endOfDay
            let utterances = db.utterances(from: day, to: next, limit: ExportWriter.unlimited)
                .filter { !$0.text.trimmed.isEmpty }
            if !utterances.isEmpty {
                var segments: [String: Segment] = [:]
                let daySegments = db.segments(from: day, to: next)
                for segment in daySegments { segments[segment.id] = segment }
                // Segments that started the day before (recording across midnight).
                for id in Set(utterances.map { $0.segmentID }) where segments[id] == nil {
                    if let segment = db.segment(id: id) { segments[id] = segment }
                }
                let key = keyFormatter.string(from: day)
                let rendered = transcriptMarkdown(day: day, key: key, utterances: utterances,
                                                  bookmarks: db.bookmarks(from: day, to: next),
                                                  segments: segments, segmentCount: daySegments.count,
                                                  recordedSeconds: db.recordedSeconds(from: day, to: next),
                                                  hasDigest: digestDays.contains(key))
                try writeText(rendered.markdown, to: directory.appendingPathComponent("\(key).md"))
                summary.transcriptDays += 1
                summary.utterances += utterances.count
                summary.words += rendered.words
                if summary.firstDay == nil { summary.firstDay = key }
                summary.lastDay = key
            }
            day = next
        }
    }

    private func transcriptMarkdown(day: Date, key: String, utterances: [Utterance], bookmarks: [StoredBookmark],
                                    segments: [String: Segment], segmentCount: Int, recordedSeconds: Double,
                                    hasDigest: Bool) -> (markdown: String, words: Int) {
        var words = 0
        for utterance in utterances {
            words += utterance.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
        let zone = TimeZone.current

        var out = "# \(titleFormatter.string(from: day))\n\n"
        out += "- Transcript: \(number(words)) words in \(number(utterances.count)) utterances\n"
        let segmentNoun = segmentCount == 1 ? "segment" : "segments"
        out += "- Recorded audio: \(ExportWriter.durationText(recordedSeconds)) in \(number(segmentCount)) \(segmentNoun)\n"
        out += "- Time zone: \(zone.identifier) (all times are local)\n"
        if hasDigest {
            out += "- Daily digest: [digests/\(key).md](../digests/\(key).md)\n"
        }
        out += "\n"

        var currentSegment: String?
        var lastStamp = ""
        var markIndex = 0
        for utterance in utterances {
            while markIndex < bookmarks.count && bookmarks[markIndex].at < utterance.startedAt {
                out += bookmarkMarkdown(bookmarks[markIndex]) + "\n\n"
                markIndex += 1
            }
            if utterance.segmentID != currentSegment {
                currentSegment = utterance.segmentID
                var headingDate = utterance.startedAt
                if let segment = segments[utterance.segmentID],
                   segment.startedAt >= day, segment.startedAt <= utterance.startedAt {
                    headingDate = segment.startedAt
                }
                let heading = timeFormatter.string(from: headingDate)
                out += "## \(heading)\n\n"
                lastStamp = heading
            }
            var paragraph = ""
            let stamp = timeFormatter.string(from: utterance.startedAt)
            if stamp != lastStamp {
                paragraph += "*\(stamp)* · "
                lastStamp = stamp
            }
            if let speaker = utterance.speaker?.nilIfEmpty {
                paragraph += "**\(ExportWriter.escaped(ExportWriter.flatten(speaker))):** "
            }
            paragraph += ExportWriter.escaped(ExportWriter.flatten(utterance.text))
            out += paragraph + "\n\n"
        }
        while markIndex < bookmarks.count {
            out += bookmarkMarkdown(bookmarks[markIndex]) + "\n\n"
            markIndex += 1
        }
        return (markdown: out.trimmingCharacters(in: .whitespacesAndNewlines) + "\n", words: words)
    }

    private func bookmarkMarkdown(_ bookmark: StoredBookmark) -> String {
        let time = timeFormatter.string(from: bookmark.at)
        switch bookmark.kind {
        case .bookmark:
            var line = "> **Bookmark** · \(time)"
            if let note = bookmark.note?.nilIfEmpty {
                line += " — " + ExportWriter.escaped(ExportWriter.flatten(note))
            }
            return line
        case .privacyPauseStart:
            return "> *Recording paused* · \(time)"
        case .privacyPauseEnd:
            return "> *Recording resumed* · \(time)"
        }
    }

    // MARK: README

    private func readme(_ summary: ExportSummary) -> String {
        let settings = SettingsStore.current
        let zone = TimeZone.current
        let zoneName = zone.abbreviation(for: now).map { "\(zone.identifier), \($0)" } ?? zone.identifier
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "unknown version"
        let exportedAt = stampFormatter.string(from: now)
        let macName = settings.effectiveMacName
        let segmentMinutes = max(1, settings.segmentSeconds / 60)
        let audioRetention = settings.keepAudioDays <= 0
            ? "right after transcription"
            : "after \(settings.keepAudioDays) day\(settings.keepAudioDays == 1 ? "" : "s")"

        var transcriptRange = ""
        if let first = summary.firstDay, let last = summary.lastDay {
            transcriptRange = first == last ? " (\(first))" : " (\(first) to \(last))"
        }
        let transcriptCount = number(summary.transcriptDays)
        let transcriptWords = number(summary.words)
        let digestCount = number(summary.digests)
        let insightCount = number(summary.insights)
        let goalCount = number(summary.goals)
        let promptCount = number(summary.prompts)
        let actionCount = number(summary.actions)

        let insightKinds = ExportWriter.codeList(InsightKind.self)
        let insightStatuses = ExportWriter.codeList(InsightStatus.self)
        let goalStatuses = ExportWriter.codeList(GoalStatus.self)
        let promptKinds = ExportWriter.codeList(PromptKind.self)
        let promptStatuses = ExportWriter.codeList(PromptStatus.self)
        let actionKinds = ExportWriter.codeList(ActionKind.self)
        let actionStatuses = ExportWriter.codeList(ActionStatus.self)

        return """
        # Earshot export

        Exported on \(exportedAt) from Earshot \(version) on “\(macName)”.
        Local times in this export are in \(zoneName). Dates inside the JSON files are ISO-8601 in UTC.

        This folder is a complete copy of what Earshot knows about your days, in open, plain-text formats \
        (Markdown and JSON). It does not need Earshot to be read: open the files in any text editor or \
        Markdown viewer, or load the JSON with any programming language. It contains private \
        conversations, so store it as carefully as the Mac it came from.

        ## Contents

        | Path | Contents |
        | --- | --- |
        | `README.md` | This description of every file and field. |
        | `Transcripts/yyyy-MM-dd.md` | \(transcriptCount) daily transcripts\(transcriptRange), \(transcriptWords) words in total. One file per local day with transcribed speech. |
        | `digests/*.md` | \(digestCount) AI-written digests: `yyyy-MM-dd.md` for one day, `week-yyyy-MM-dd.md` for the weekly review ending on that day. |
        | `insights.json` | \(insightCount) items Earshot extracted from the transcript (tasks, commitments, events, ideas, goals, people, facts, decisions, questions, highlights, moods). |
        | `goals.json` | \(goalCount) goals with their progress notes. |
        | `prompts.json` | \(promptCount) questions, nudges, approvals, answers and notices Earshot prepared for the watch, with your answers. |
        | `actions.json` | \(actionCount) actions Earshot proposed or carried out on the Mac, with their results. |

        Not included: raw audio (Earshot deletes it \(audioRetention); transcripts are kept), the \
        memory-chat history, paired devices, settings and API keys.

        ## Transcripts/yyyy-MM-dd.md

        Markdown, one file per local calendar day (midnight to midnight in the time zone above). Days \
        without any transcribed speech have no file.

        - The first line (for example `# Saturday, November 14, 2026`) names the day. A short list follows \
        with the number of words and utterances, how much audio was recorded and in how many segments, the \
        time zone and, when one exists, a link to that day's digest.
        - `## 3:42 PM` starts a recording segment: the watch or the Mac records in chunks of about \
        \(segmentMinutes) minute(s), and the heading is the local time the segment started.
        - Each paragraph under a heading is one utterance, a sentence-like piece of speech recognised from \
        the audio. When the clock minute changes within a segment, the paragraph starts with the time in \
        italics (`*3:44 PM* ·`). `**Name:**` marks the speaker when Earshot knows who spoke.
        - `> **Bookmark** · 3:45 PM — note` marks a moment you bookmarked on the watch (the note is \
        optional). `> *Recording paused* · …` and `> *Recording resumed* · …` mark privacy pauses.
        - The text comes from automatic speech recognition and can contain mistakes. Characters Markdown \
        would treat as formatting are escaped with a backslash.

        ## digests/*.md

        Markdown written by the AI companion. A daily digest holds the day's summary, highlights, \
        commitments, open loops, progress on goals, patterns, a reflection question and suggestions for \
        the next day. A weekly review covers the seven days ending on the date in its file name.

        ## JSON files

        - UTF-8, pretty-printed, keys sorted alphabetically.
        - Each file holds one JSON array of objects, oldest first (by `createdAt`).
        - Dates are ISO-8601 strings in UTC, for example `2026-11-14T23:42:05Z`.
        - Fields marked "optional" are left out when they have no value.
        - `id` fields are unique identifiers that other records refer to (for example `relatedID` and \
        `sourceInsightID`).

        ### insights.json: things Earshot noticed

        | Field | Type | Meaning |
        | --- | --- | --- |
        | `id` | string | Unique id. |
        | `kind` | string | One of \(insightKinds). |
        | `title` | string | One-line summary. Commitments start with “You promised:” or “Promised to you:”. |
        | `detail` | string | Longer explanation or context (may be empty). |
        | `dueAt` | date, optional | When a task, commitment or event is due. |
        | `people` | array of strings | People involved (may be empty). |
        | `sourceFrom`, `sourceTo` | date, optional | The stretch of transcript the item came from; find it in `Transcripts/`. |
        | `status` | string | One of \(insightStatuses): still open, done, or dismissed by you. |
        | `confidence` | number | 0 to 1: how sure the AI was. |
        | `createdAt` | date | When it was captured. |

        ### goals.json: your goals

        | Field | Type | Meaning |
        | --- | --- | --- |
        | `id` | string | Unique id. |
        | `title` | string | The goal. |
        | `why` | string | Why it matters to you (may be empty). |
        | `status` | string | One of \(goalStatuses). |
        | `createdAt` | date | When the goal was added. |
        | `lastCheckIn` | date, optional | The last time Earshot checked in on progress. |
        | `notes` | array | Progress notes, each `{ "date": date, "text": string }`. |

        ### prompts.json: what Earshot asked or told you on the watch

        | Field | Type | Meaning |
        | --- | --- | --- |
        | `id` | string | Unique id. |
        | `kind` | string | One of \(promptKinds): `question` (asked to help you), `approval` (approve or deny an action on the Mac), `answer` (reply to something you asked from the wrist), `nudge` (reminder about a commitment or goal), `digest` (a summary is ready), `info`. |
        | `title`, `body` | string | The text shown on the watch. |
        | `choices` | array | Buttons offered, each `{ "id": string, "title": string }`. |
        | `allowsFreeText` | boolean | Whether a typed or dictated answer was possible. |
        | `allowsVoice` | boolean | Whether you could answer by simply speaking. |
        | `priority` | integer | 1 (low) to 5 (urgent). |
        | `status` | string | One of \(promptStatuses). `queued`: a candidate not yet sent; `pending`: sent to the watch; `delivered`: shown on the watch; `awaitingVoice`: waiting for your spoken answer; then `answered`, `dismissed` or `expired`. |
        | `rationale` | string | Why Earshot asked; for questions, the decision the answer unlocks. |
        | `relatedID` | string, optional | Id of the related insight, goal, action, approval or request. |
        | `answerText` | string, optional | Your answer in words. |
        | `answerChoiceID` | string, optional | The id of the choice you picked. |
        | `createdAt` | date | When it was created. |
        | `releasedAt`, `deliveredAt`, `answeredAt` | date, optional | When it was sent, shown and answered. |
        | `expiresAt` | date, optional | After this time it was no longer shown. |
        | `notBefore` | date, optional | It was held back until this time (snoozed or scheduled). |

        ### actions.json: actions on the Mac

        | Field | Type | Meaning |
        | --- | --- | --- |
        | `id` | string | Unique id. |
        | `kind` | string | One of \(actionKinds). |
        | `title` | string | What the action does. |
        | `rationale` | string | Why it was proposed. |
        | `payload` | object | Details; only the fields relevant to the kind are present (see below). |
        | `status` | string | One of \(actionStatuses). |
        | `result` | string, optional | The outcome message after it ran. |
        | `sourceInsightID` | string, optional | The item in `insights.json` it came from. |
        | `createdAt` | date | When it was proposed. |
        | `executedAt` | date, optional | When it ran. |

        `payload` fields, all optional strings: `notes`; `dueISO`, `startISO`, `endISO` (dates exactly as \
        the AI wrote them: ISO-8601 local time with a UTC offset, or a date only); `location`; `url`; \
        `appName`; `recipient`; `subject`; `body`; `shortcutName`; `input` (text passed to a Shortcut); \
        `script` (AppleScript source); `task` (instructions for the computer agent).

        """
    }

    // MARK: Writing

    private func writeJSON<T: Encodable>(_ value: T, named name: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity",
                                                                      negativeInfinity: "-Infinity",
                                                                      nan: "NaN")
        var data = try encoder.encode(value)
        data.append(contentsOf: [10])
        try data.write(to: root.appendingPathComponent(name), options: .atomic)
    }

    private func writeText(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    // MARK: Formatting

    private func number(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func durationText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0 min" }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 1 { return "under a minute" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    /// "`a`, `b`, `c`" for every raw value of a string enum.
    private static func codeList<T: CaseIterable & RawRepresentable>(_ type: T.Type) -> String where T.RawValue == String {
        T.allCases.map { "`" + $0.rawValue + "`" }.joined(separator: ", ")
    }

    /// Collapses newlines and runs of whitespace into single spaces.
    private static func flatten(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }

    /// Backslash-escapes characters Markdown would read as formatting.
    private static func escaped(_ text: String) -> String {
        let special: Set<Character> = ["\\", "`", "*", "_", "[", "]", "<", ">", "#", "|", "~"]
        var out = ""
        out.reserveCapacity(text.count + 8)
        for character in text {
            if special.contains(character) { out.append("\\") }
            out.append(character)
        }
        // A paragraph starting with "-", "+", "=" or "12." / "12)" would become a list or heading.
        if let first = out.first, first == "-" || first == "+" || first == "=" {
            out = "\\" + out
        } else {
            let digits = out.prefix(while: { $0.isASCII && $0.isNumber })
            if !digits.isEmpty && digits.count < out.count {
                let marker = out[out.index(out.startIndex, offsetBy: digits.count)]
                if marker == "." || marker == ")" {
                    out = String(digits) + "\\" + String(out.dropFirst(digits.count))
                }
            }
        }
        return out
    }

    /// Digest keys are "yyyy-MM-dd" / "week-yyyy-MM-dd"; keep any other key file-system safe.
    private static func safeFileName(_ name: String) -> String {
        let cleaned = String(name.map { character -> Character in
            character == "/" || character == ":" || character == "\\" ? "-" : character
        }).trimmed
        return cleaned.isEmpty ? "digest" : cleaned
    }
}
