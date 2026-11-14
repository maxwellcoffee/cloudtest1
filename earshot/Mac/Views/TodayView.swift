//  TodayView.swift
//  The day at a glance: stats, the live transcript timeline grouped by segment
//  (with bookmarks and pending segments), search, and the insights rail.
//  Audio files dropped on the view are imported and transcribed.

import SwiftUI
import AppKit

struct EarshotTodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var showInsights = true
    @State private var dropTargeted = false
    @State private var forgetRequest: TodayForgetRequest? = nil
    @State private var showCustomForget = false

    var body: some View {
        VStack(spacing: 0) {
            TodayHeader()
            Divider()
            HStack(spacing: 0) {
                TranscriptPane(query: query)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showInsights {
                    Divider()
                    InsightsRail()
                        .frame(width: 320)
                }
            }
        }
        .navigationTitle(EarshotFormat.dayTitle(model.selectedDay))
        .searchable(text: $query, placement: .toolbar, prompt: "Search transcript")
        .toolbar { toolbarContent }
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter { $0.isFileURL }
            guard !files.isEmpty else { return false }
            model.importAudioFiles(files)
            return true
        } isTargeted: { targeted in
            dropTargeted = targeted
        }
        .overlay {
            if dropTargeted {
                DropHint()
            }
        }
        .confirmationDialog(forgetRequest?.title ?? "Forget",
                            isPresented: forgetDialogBinding,
                            titleVisibility: .visible,
                            presenting: forgetRequest) { request in
            Button("Forget", role: .destructive) {
                model.forget(from: request.from, to: request.to)
            }
            Button("Cancel", role: .cancel) {}
        } message: { request in
            Text("The transcript and recorded audio from \(request.from.timeText) to \(request.to.timeText) will be deleted permanently.")
        }
        .sheet(isPresented: $showCustomForget) {
            ForgetRangeSheet(day: model.selectedDay) { from, to in
                model.forget(from: from, to: to)
            }
        }
    }

    private var forgetDialogBinding: Binding<Bool> {
        Binding(get: { forgetRequest != nil }, set: { presented in
            if !presented { forgetRequest = nil }
        })
    }

    private var dayBinding: Binding<Date> {
        Binding(get: { model.selectedDay }, set: { model.selectedDay = $0.startOfDay })
    }

    private func shiftDay(_ days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: model.selectedDay) else { return }
        model.selectedDay = min(next, Date()).startOfDay
    }

    private func requestForget(minutes: Int) {
        let end = Date()
        let start = end.addingTimeInterval(-Double(minutes) * 60)
        let title = minutes >= 60 ? "Forget the last hour?" : "Forget the last \(minutes) minutes?"
        forgetRequest = TodayForgetRequest(title: title, from: start, to: end)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                shiftDay(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("Previous day")

            DatePicker("Day", selection: dayBinding, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)

            Button {
                shiftDay(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(model.isViewingToday)
            .help("Next day")

            // Also enabled on today after a jump to a cited utterance: it returns to the live transcript.
            Button("Today") {
                model.highlightedUtteranceID = nil
                model.selectedDay = Date().startOfDay
            }
            .disabled(model.isViewingToday && model.highlightedUtteranceID == nil)
            .help(model.isViewingToday ? "Back to the live transcript" : "Go to today")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button("Last 5 Minutes") { requestForget(minutes: 5) }
                Button("Last 15 Minutes") { requestForget(minutes: 15) }
                Button("Last Hour") { requestForget(minutes: 60) }
                Divider()
                Button("Choose a Time Range…") { showCustomForget = true }
            } label: {
                Label("Forget", systemImage: "eye.slash")
            }
            .help("Delete part of the transcript")

            Button {
                model.presentImportPanel()
            } label: {
                Label("Import Audio", systemImage: "square.and.arrow.down")
            }
            .help("Import audio recordings to transcribe")

            Toggle(isOn: $showInsights) {
                Label("Insights", systemImage: "sidebar.right")
            }
            .help(showInsights ? "Hide insights" : "Show insights")
        }
    }
}

private struct TodayForgetRequest {
    var title: String
    var from: Date
    var to: Date
}

// MARK: - Header

private struct TodayHeader: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                EarshotStatTile("Words", value: EarshotFormat.count(model.dayWordCount), symbol: "text.bubble")
                EarshotStatTile("Recorded", value: EarshotFormat.duration(model.dayRecordedSeconds),
                                symbol: "waveform", tint: .pink)
                EarshotStatTile("Segments", value: EarshotFormat.count(model.segments.count),
                                symbol: "square.stack.3d.down.right", tint: .indigo)
                EarshotStatTile("Open tasks", value: EarshotFormat.count(model.openTaskCount),
                                symbol: "checklist", tint: .orange)
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Label(model.pipelineStatus, systemImage: "waveform.path")
                    if model.importsInProgress > 0 {
                        Label("Importing \(model.importsInProgress)…", systemImage: "square.and.arrow.down")
                    }
                    if model.micRecorder.isRecording {
                        Label("Mac microphone on", systemImage: "mic.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            if !model.aiConfigured {
                EarshotNotice("AI is off. Add an Anthropic API key in Settings → AI to get insights, questions and digests.",
                              symbol: "sparkles", tint: .orange, actionTitle: "Open Settings") {
                    model.sidebarSelection = .settings
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Timeline model

private struct TranscriptGroup {
    let id: String
    let segment: Segment?
    let utterances: [Utterance]

    var start: Date { utterances.first?.startedAt ?? segment?.startedAt ?? .distantPast }
    var end: Date { utterances.last?.endedAt ?? segment?.endedAt ?? start }
}

private enum TimelineItem: Identifiable {
    case group(TranscriptGroup)
    case bookmark(StoredBookmark)
    case pending(Segment)

    var id: String {
        switch self {
        case .group(let group): return "g-" + group.id
        case .bookmark(let bookmark): return "b-" + bookmark.id
        case .pending(let segment): return "p-" + segment.id
        }
    }

    var date: Date {
        switch self {
        case .group(let group): return group.start
        case .bookmark(let bookmark): return bookmark.at
        case .pending(let segment): return segment.startedAt
        }
    }

    func contains(utteranceID: Int64) -> Bool {
        if case .group(let group) = self {
            return group.utterances.contains { $0.id == utteranceID }
        }
        return false
    }
}

private enum TimelineBuilder {
    static func build(segments: [Segment], utterances: [Utterance], bookmarks: [StoredBookmark],
                      query: String) -> [TimelineItem] {
        let needle = query.trimmed
        let matching: [Utterance]
        if needle.isEmpty {
            matching = utterances
        } else {
            matching = utterances.filter { utterance in
                utterance.text.localizedCaseInsensitiveContains(needle)
                    || (utterance.speaker?.localizedCaseInsensitiveContains(needle) ?? false)
            }
        }

        var order: [String] = []
        var bySegment: [String: [Utterance]] = [:]
        for utterance in matching {
            if bySegment[utterance.segmentID] == nil {
                order.append(utterance.segmentID)
            }
            bySegment[utterance.segmentID, default: []].append(utterance)
        }
        let segmentsByID = Dictionary(segments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var items: [TimelineItem] = order.map { segmentID in
            TimelineItem.group(TranscriptGroup(id: segmentID, segment: segmentsByID[segmentID],
                                               utterances: bySegment[segmentID] ?? []))
        }
        if needle.isEmpty {
            for segment in segments where bySegment[segment.id] == nil {
                switch segment.status {
                case .received, .transcribing, .failed:
                    items.append(TimelineItem.pending(segment))
                case .transcribed, .silent:
                    break
                }
            }
            items.append(contentsOf: bookmarks.map { TimelineItem.bookmark($0) })
        } else {
            let matches = bookmarks.filter { ($0.note ?? "").localizedCaseInsensitiveContains(needle) }
            items.append(contentsOf: matches.map { TimelineItem.bookmark($0) })
        }
        return items.sorted { $0.date < $1.date }
    }

    /// Number of utterances shown in the timeline items.
    static func utteranceCount(_ items: [TimelineItem]) -> Int {
        var total = 0
        for item in items {
            if case .group(let group) = item {
                total += group.utterances.count
            }
        }
        return total
    }

    /// Bolds every case- and diacritic-insensitive occurrence of `query`.
    static func highlight(_ text: String, query: String) -> AttributedString {
        let needle = query.trimmed
        guard !needle.isEmpty else { return AttributedString(text) }
        var result = AttributedString()
        var cursor = text.startIndex
        while cursor < text.endIndex,
              let range = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive],
                                     range: cursor..<text.endIndex) {
            if cursor < range.lowerBound {
                result.append(AttributedString(String(text[cursor..<range.lowerBound])))
            }
            var match = AttributedString(String(text[range]))
            match.inlinePresentationIntent = .stronglyEmphasized
            result.append(match)
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            result.append(AttributedString(String(text[cursor...])))
        }
        return result
    }
}

// MARK: - Transcript

private struct TranscriptPane: View {
    @EnvironmentObject var model: AppModel
    let query: String
    @State var pendingScrollID: Int64? = nil
    @State var archiveResults: [Utterance] = []
    @State var archiveLoading = false
    @State var showArchive = false

    private static let bottomID = "transcript-bottom"

    var body: some View {
        let items = TimelineBuilder.build(segments: model.segments, utterances: model.utterances,
                                          bookmarks: model.bookmarks, query: query)
        VStack(spacing: 0) {
            if !query.trimmed.isEmpty {
                SearchScopeBar(matchCount: TimelineBuilder.utteranceCount(items), showArchive: $showArchive,
                               archiveCount: archiveResults.count, loading: archiveLoading)
                Divider()
            }
            if showArchive && !query.trimmed.isEmpty {
                ArchiveResultsList(results: archiveResults, query: query, loading: archiveLoading,
                                   showArchive: $showArchive)
            } else if items.isEmpty {
                TranscriptEmptyState(query: query)
            } else {
                timeline(items)
            }
        }
        .task(id: query) {
            await searchArchive()
        }
    }

    private func timeline(_ items: [TimelineItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(items) { item in
                        TimelineRow(item: item, query: query, highlightedID: model.highlightedUtteranceID)
                            .id(item.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomID)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .defaultScrollAnchor(model.isViewingToday && query.isEmpty ? UnitPoint.bottom : UnitPoint.top)
            .onChange(of: model.utterances.count) {
                if let target = pendingScrollID {
                    scroll(to: target, in: items, proxy: proxy)
                } else if model.isViewingToday && query.isEmpty && model.highlightedUtteranceID == nil {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(Self.bottomID, anchor: .bottom)
                    }
                }
            }
            .onChange(of: model.highlightedUtteranceID, initial: true) { oldValue, newValue in
                guard let target = newValue else {
                    // The jump ended (Today button, day change): follow the live transcript again.
                    pendingScrollID = nil
                    if oldValue != nil && model.isViewingToday && query.isEmpty {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(Self.bottomID, anchor: .bottom)
                        }
                    }
                    return
                }
                pendingScrollID = target
                scroll(to: target, in: items, proxy: proxy)
            }
        }
    }

    private func scroll(to utteranceID: Int64, in items: [TimelineItem], proxy: ScrollViewProxy) {
        guard let item = items.first(where: { $0.contains(utteranceID: utteranceID) }) else { return }
        pendingScrollID = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(item.id, anchor: .center)
        }
    }

    private func searchArchive() async {
        let text = query.trimmed
        guard text.count >= 2 else {
            archiveResults = []
            archiveLoading = false
            return
        }
        // Debounce typing.
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        archiveLoading = true
        let results = await model.searchArchive(text)
        guard !Task.isCancelled else { return }
        archiveResults = results
        archiveLoading = false
    }
}

private struct SearchScopeBar: View {
    let matchCount: Int
    @Binding var showArchive: Bool
    let archiveCount: Int
    let loading: Bool

    var body: some View {
        HStack(spacing: 12) {
            Picker("Search in", selection: $showArchive) {
                Text("This day (\(matchCount))").tag(false)
                Text(loading ? "All days…" : "All days (\(archiveCount))").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

private struct ArchiveResultsList: View {
    @EnvironmentObject var model: AppModel
    let results: [Utterance]
    let query: String
    let loading: Bool
    @Binding var showArchive: Bool

    var body: some View {
        if results.isEmpty {
            if loading {
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView.search(text: query)
            }
        } else {
            List(results) { utterance in
                Button {
                    // Switch to the day's timeline so the jump to the utterance is visible.
                    showArchive = false
                    model.show(date: utterance.startedAt, utteranceID: utterance.id)
                    model.showBanner(.info, "Showing \(EarshotFormat.dayTitle(utterance.startedAt)) at \(utterance.startedAt.timeText).")
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(utterance.startedAt.shortText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(TimelineBuilder.highlight(utterance.text, query: query))
                            .lineLimit(3)
                    }
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
    }
}

private struct TimelineRow: View {
    let item: TimelineItem
    let query: String
    let highlightedID: Int64?

    var body: some View {
        switch item {
        case .group(let group):
            TranscriptGroupRow(group: group, query: query, highlightedID: highlightedID)
        case .bookmark(let bookmark):
            BookmarkRow(bookmark: bookmark)
        case .pending(let segment):
            PendingSegmentRow(segment: segment)
        }
    }
}

private struct TranscriptGroupRow: View {
    let group: TranscriptGroup
    let query: String
    let highlightedID: Int64?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .trailing, spacing: 3) {
                Text(group.start.timeText)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text(EarshotFormat.duration(group.end.timeIntervalSince(group.start)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let device = group.segment?.device {
                    Image(systemName: TimelineRowStyle.symbol(forDevice: device))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(TimelineRowStyle.label(forDevice: device))
                }
            }
            .frame(width: 78, alignment: .trailing)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(group.utterances) { utterance in
                    UtteranceLine(utterance: utterance, query: query, highlighted: utterance.id == highlightedID)
                }
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

private struct UtteranceLine: View {
    let utterance: Utterance
    let query: String
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let speaker = utterance.speaker?.nilIfEmpty {
                Text(speaker)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(TimelineBuilder.highlight(utterance.text, query: query))
                .font(.body)
                .lineSpacing(2)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, highlighted ? 6 : 0)
        .padding(.vertical, highlighted ? 3 : 0)
        .background(highlighted ? Color.accentColor.opacity(0.16) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(EarshotFormat.timeRange(utterance.startedAt, utterance.endedAt))
    }
}

private enum TimelineRowStyle {
    static func symbol(forDevice device: String) -> String {
        let lower = device.lowercased()
        if lower.contains("import") { return "square.and.arrow.down" }
        if lower.contains("mac") { return "desktopcomputer" }
        return "applewatch"
    }

    static func label(forDevice device: String) -> String {
        let lower = device.lowercased()
        if lower.contains("import") { return "Imported audio" }
        if lower.contains("mac") { return "This Mac's microphone" }
        return "Recorded on \(device)"
    }
}

private struct BookmarkRow: View {
    let bookmark: StoredBookmark

    private var title: String {
        switch bookmark.kind {
        case .bookmark: return "Bookmarked this moment"
        case .privacyPauseStart: return "Recording paused"
        case .privacyPauseEnd: return "Recording resumed"
        }
    }

    private var symbol: String {
        switch bookmark.kind {
        case .bookmark: return "flag.fill"
        case .privacyPauseStart: return "pause.circle.fill"
        case .privacyPauseEnd: return "play.circle.fill"
        }
    }

    private var tint: Color {
        switch bookmark.kind {
        case .bookmark: return .orange
        case .privacyPauseStart: return .secondary
        case .privacyPauseEnd: return .green
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(bookmark.at.timeText)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.callout.weight(.medium))
                if let note = bookmark.note?.nilIfEmpty {
                    Text("· \(note)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.1), in: Capsule())
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct PendingSegmentRow: View {
    let segment: Segment

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(segment.startedAt.timeText)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
            HStack(spacing: 8) {
                switch segment.status {
                case .received:
                    Image(systemName: "clock")
                    Text("Waiting to transcribe \(EarshotFormat.duration(segment.duration))")
                case .transcribing:
                    ProgressView()
                        .controlSize(.small)
                    Text("Transcribing \(EarshotFormat.duration(segment.duration))…")
                case .failed:
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Transcription failed: \(segment.error ?? "unknown error")")
                        .lineLimit(2)
                case .transcribed, .silent:
                    EmptyView()
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct TranscriptEmptyState: View {
    @EnvironmentObject var model: AppModel
    let query: String

    var body: some View {
        if !query.trimmed.isEmpty {
            ContentUnavailableView.search(text: query)
        } else if model.isViewingToday {
            ContentUnavailableView {
                Label("Nothing transcribed yet today", systemImage: "waveform")
            } description: {
                VStack(spacing: 10) {
                    Text("Pair your Apple Watch in Devices and start recording, or turn on this Mac's microphone when you're at your desk. You can also drop audio files here.")
                    TodayPrivacyNote(store: model.settings)
                }
            } actions: {
                HStack(spacing: 10) {
                    Button("Pair a Watch") {
                        model.sidebarSelection = .devices
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Use Mac Microphone") {
                        model.setMacMicEnabled(true)
                    }
                    Button("Import Audio…") {
                        model.presentImportPanel()
                    }
                }
            }
        } else {
            ContentUnavailableView {
                Label("Nothing recorded on \(EarshotFormat.dayTitle(model.selectedDay))", systemImage: "calendar")
            } description: {
                Text("Pick another day, or import recordings from that day.")
            } actions: {
                Button("Go to Today") {
                    model.selectedDay = Date().startOfDay
                }
            }
        }
    }
}

/// One line in the empty state about local redaction before the cloud.
private struct TodayPrivacyNote: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Label {
            Text(store.settings.redactBeforeCloud
                 ? "Privacy: transcripts are stored only on this Mac. Before text is sent to Claude, e-mail addresses, phone, card and account numbers, Social Security numbers and one-time codes are replaced with placeholders, right here on your Mac."
                 : "Privacy: transcripts are stored only on this Mac. Redaction of personal details before text is sent to Claude is off; turn it on in Settings → Data.")
        } icon: {
            Image(systemName: "lock.shield")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

private struct DropHint: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 34))
                Text("Drop audio files to transcribe them")
                    .font(.headline)
            }
            .foregroundStyle(Color.accentColor)
        }
        .padding(16)
        .allowsHitTesting(false)
    }
}

// MARK: - Insights rail

private struct InsightsRail: View {
    @EnvironmentObject var model: AppModel

    private static let order: [InsightKind] = [.task, .commitment, .event, .decision, .question, .idea,
                                               .goal, .person, .fact, .highlight, .mood]

    var body: some View {
        let open = model.insights.filter { $0.status == .open }
        let done = Array(model.insights.filter { $0.status == .done }.prefix(5))
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RailHeader()
                if open.isEmpty {
                    Text(model.aiConfigured
                         ? "Tasks, commitments, decisions and people Earshot notices will appear here."
                         : "Turn on AI in Settings to extract tasks, commitments and decisions from what you say.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Self.order, id: \.self) { kind in
                    InsightKindSection(kind: kind, items: open.filter { $0.kind == kind })
                }
                if !done.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Done recently")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(done) { insight in
                            DoneInsightRow(insight: insight)
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.35))
    }
}

private struct RailHeader: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Insights")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    model.analyzeNow()
                } label: {
                    if model.isAnalyzing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(model.isAnalyzing)
                .help("Analyze now")
            }
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                if let at = model.lastAnalysisAt, !model.isAnalyzing {
                    Text("\(model.analysisStatus) · \(at.relativeText)")
                } else {
                    Text(model.analysisStatus)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
    }
}

private struct InsightKindSection: View {
    let kind: InsightKind
    let items: [Insight]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: kind.symbol)
                        .foregroundStyle(EarshotPalette.color(for: kind))
                    Text(Self.plural(kind))
                        .font(.subheadline.weight(.semibold))
                    Text("\(items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }

    private static func plural(_ kind: InsightKind) -> String {
        switch kind {
        case .person: return "People"
        case .mood: return "Mood"
        default: return kind.label + "s"
        }
    }
}

private struct InsightCard: View {
    @EnvironmentObject var model: AppModel
    let insight: Insight
    @State var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = insight.detail.nilIfEmpty, detail != insight.title.trimmed {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                InsightMeta(insight: insight)
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Button {
                    model.setStatus(.done, for: insight)
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .help("Mark done")
                Button {
                    model.setStatus(.dismissed, for: insight)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Dismiss")
            }
            .buttonStyle(.borderless)
            .font(.body)
            .opacity(hovering ? 1 : 0.4)
        }
        .padding(10)
        .background(EarshotPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(EarshotPalette.cardBorder, lineWidth: 1)
        )
        .onHover { inside in
            hovering = inside
        }
        .contextMenu {
            if insight.sourceFrom != nil {
                Button("Show in Transcript") {
                    model.showSource(of: insight)
                }
            }
            if insight.kind == .task || insight.kind == .commitment || insight.kind == .event {
                Button("Add to Reminders") {
                    model.createReminder(from: insight)
                }
            }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                let text = insight.detail.nilIfEmpty.map { "\(insight.title)\n\($0)" } ?? insight.title
                NSPasteboard.general.setString(text, forType: .string)
            }
            Divider()
            Button("Mark Done") { model.setStatus(.done, for: insight) }
            Button("Dismiss") { model.setStatus(.dismissed, for: insight) }
        }
    }
}

private struct InsightMeta: View {
    let insight: Insight

    var body: some View {
        let people = Array(insight.people.prefix(3))
        if insight.dueAt != nil || !people.isEmpty || insight.confidence < 0.6 {
            HStack(spacing: 4) {
                if let due = insight.dueAt {
                    EarshotChip(due.shortText, symbol: "clock", tint: due < Date() ? .red : .orange)
                }
                ForEach(people, id: \.self) { person in
                    EarshotChip(person, symbol: "person", tint: .teal)
                }
                if insight.confidence < 0.6 {
                    EarshotChip("Unsure", symbol: "questionmark", tint: .secondary)
                }
            }
        }
    }
}

private struct DoneInsightRow: View {
    @EnvironmentObject var model: AppModel
    let insight: Insight

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(insight.title)
                .strikethrough()
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("Reopen") {
                model.setStatus(.open, for: insight)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .font(.caption)
    }
}

// MARK: - Forget sheet

private struct ForgetRangeSheet: View {
    @Environment(\.dismiss) var dismiss
    let onForget: (Date, Date) -> Void
    @State var from: Date
    @State var to: Date

    init(day: Date, onForget: @escaping (Date, Date) -> Void) {
        self.onForget = onForget
        let end = Calendar.current.isDateInToday(day) ? Date() : day.endOfDay.addingTimeInterval(-60)
        _from = State(initialValue: end.addingTimeInterval(-1800))
        _to = State(initialValue: end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Forget part of the transcript")
                .font(.headline)
            Text("Everything said in this range is deleted from Earshot's archive: the transcript and the recorded audio. This can't be undone.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DatePicker("From", selection: $from, displayedComponents: [.date, .hourAndMinute])
            DatePicker("To", selection: $to, displayedComponents: [.date, .hourAndMinute])
            if to <= from {
                Text("The end must be after the start.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Forget", role: .destructive) {
                    onForget(from, to)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(to <= from)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
