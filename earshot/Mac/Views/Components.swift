//  Components.swift
//  Small reusable SwiftUI pieces shared by the Mac views. Every top-level name
//  carries the `Earshot` prefix so it cannot collide with other modules.

import SwiftUI
import AppKit

// MARK: - Formatting

enum EarshotFormat {
    /// The computer's name, resolved once (the host name lookup can be slow).
    static let defaultMacName: String = AppSettings().effectiveMacName

    /// "45 s", "12 min", "1 h 5 min".
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0 min" }
        if seconds < 60 { return "\(Int(seconds.rounded())) s" }
        let totalMinutes = Int((seconds / 60).rounded())
        if totalMinutes < 60 { return "\(totalMinutes) min" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }

    static func count(_ value: Int) -> String {
        value.formatted()
    }

    static func battery(_ level: Float) -> String {
        guard level.isFinite, level >= 0 else { return "Battery unknown" }
        let percent = Int((min(1, level) * 100).rounded())
        return "\(percent)%"
    }

    static func batterySymbol(_ level: Float) -> String {
        guard level.isFinite, level >= 0 else { return "battery.0" }
        switch level {
        case ..<0.15: return "battery.0"
        case ..<0.4: return "battery.25"
        case ..<0.65: return "battery.50"
        case ..<0.9: return "battery.75"
        default: return "battery.100"
        }
    }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    /// "Today", "Yesterday", "Thursday, Nov 12".
    static func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMM d")
        return formatter.string(from: date)
    }

    /// "3:42 – 3:45 PM".
    static func timeRange(_ start: Date, _ end: Date) -> String {
        guard end > start.addingTimeInterval(59) else { return start.timeText }
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: start, to: end)
    }

    /// Parses a "yyyy-MM-dd" day key (local time).
    static func date(fromDayKey key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    static func isWeeklyDigest(_ key: String) -> Bool {
        key.hasPrefix("week-")
    }

    /// "Saturday, Nov 14" or "Week ending Nov 14".
    static func digestTitle(_ key: String) -> String {
        if isWeeklyDigest(key) {
            let dayKey = String(key.dropFirst("week-".count))
            guard let endDay = EarshotFormat.date(fromDayKey: dayKey) else { return "Weekly review" }
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            return "Week ending \(formatter.string(from: endDay))"
        }
        guard let day = EarshotFormat.date(fromDayKey: key) else { return key }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMM d")
        return formatter.string(from: day)
    }

    static func hourLabel(_ hour: Int) -> String {
        guard let date = Calendar.current.date(bySettingHour: max(0, min(23, hour)), minute: 0, second: 0, of: Date()) else {
            return "\(hour):00"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Pretty-prints an ISO date from an action payload, falling back to the raw text.
    static func payloadDate(_ raw: String?) -> String? {
        guard let text = raw?.nilIfEmpty else { return nil }
        guard let parsed = DateParsing.parse(text) else { return text }
        if DateParsing.isDateOnly(text) {
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
            return formatter.string(from: parsed)
        }
        return parsed.shortText
    }
}

// MARK: - Colors

enum EarshotPalette {
    static func color(for kind: InsightKind) -> Color {
        switch kind {
        case .task: return .orange
        case .commitment: return .pink
        case .event: return .red
        case .idea: return .yellow
        case .goal: return .green
        case .person: return .teal
        case .fact: return .blue
        case .decision: return .purple
        case .question: return .indigo
        case .highlight: return .mint
        case .mood: return .cyan
        }
    }

    static func color(for risk: RiskLevel) -> Color {
        switch risk {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    static func color(for status: ActionStatus) -> Color {
        switch status {
        case .proposed: return .blue
        case .approved: return .indigo
        case .running: return .orange
        case .done: return .green
        case .failed: return .red
        case .rejected: return .gray
        }
    }

    static func color(for style: AppModel.Banner.Style) -> Color {
        switch style {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    static var cardBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var cardBorder: Color { Color.primary.opacity(0.07) }
}

// MARK: - System Settings

enum EarshotSystemSettings {
    /// Opens a pane of System Settings → Privacy & Security, e.g. "Privacy_Calendars".
    static func openPrivacyPane(_ anchor: String) {
        let raw = "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        guard let url = URL(string: raw) else { return }
        if !NSWorkspace.shared.open(url) {
            Log.error("Could not open System Settings pane \(anchor).")
        }
    }
}

// MARK: - Containers

/// A calm rounded card on the control background color.
struct EarshotCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EarshotPalette.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(EarshotPalette.cardBorder, lineWidth: 1)
            )
    }
}

/// Section title with an optional symbol, count and subtitle.
struct EarshotSectionHeader: View {
    private let title: String
    private let symbol: String?
    private let count: Int?
    private let subtitle: String?

    init(_ title: String, symbol: String? = nil, count: Int? = nil, subtitle: String? = nil) {
        self.title = title
        self.symbol = symbol
        self.count = count
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.title3.weight(.semibold))
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer(minLength: 0)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Small views

struct EarshotStatusDot: View {
    private let color: Color
    private let size: CGFloat

    init(_ color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.45), radius: 2)
    }
}

/// Capsule label for statuses, people, dates.
struct EarshotChip: View {
    private let text: String
    private let symbol: String?
    private let tint: Color

    init(_ text: String, symbol: String? = nil, tint: Color = .secondary) {
        self.text = text
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct EarshotRiskChip: View {
    private let risk: RiskLevel

    init(_ risk: RiskLevel) {
        self.risk = risk
    }

    var body: some View {
        EarshotChip("\(risk.rawValue.capitalized) risk", symbol: risk == .high ? "exclamationmark.shield" : "shield",
                    tint: EarshotPalette.color(for: risk))
    }
}

/// A number with a label, used in stats headers.
struct EarshotStatTile: View {
    private let title: String
    private let value: String
    private let symbol: String
    private let tint: Color

    init(_ title: String, value: String, symbol: String, tint: Color = .accentColor) {
        self.title = title
        self.value = value
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(EarshotPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(EarshotPalette.cardBorder, lineWidth: 1)
        )
    }
}

/// Horizontal audio level meter for a dBFS value (-60...0).
struct EarshotLevelMeter: View {
    private let level: Float
    private let active: Bool

    init(level: Float, active: Bool = true) {
        self.level = level
        self.active = active
    }

    private var fraction: Double {
        guard active, level.isFinite else { return 0 }
        let clamped = min(0, max(-60, level))
        return Double((clamped + 60) / 60)
    }

    var body: some View {
        let value = fraction
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [.green, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, proxy.size.width * CGFloat(value)))
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.15), value: value)
        .accessibilityLabel("Input level")
        .accessibilityValue(level.isFinite ? "\(Int(level.rounded())) decibels" : "silent")
    }
}

/// A warning / info strip with an optional action.
struct EarshotNotice: View {
    private let text: String
    private let symbol: String
    private let tint: Color
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(_ text: String, symbol: String = "exclamationmark.triangle.fill", tint: Color = .orange,
         actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.text = text
        self.symbol = symbol
        self.tint = tint
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Permissions

/// One permission with its state and a button to request or fix it.
struct EarshotPermissionRow: View {
    enum Access {
        case granted, denied, notDetermined, info
    }

    private let title: String
    private let detail: String
    private let symbol: String
    private let access: Access
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(_ title: String, detail: String, symbol: String, access: Access,
         actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.access = access
        self.actionTitle = actionTitle
        self.action = action
    }

    private var statusText: String {
        switch access {
        case .granted: return "Allowed"
        case .denied: return "Not allowed"
        case .notDetermined: return "Not requested"
        case .info: return ""
        }
    }

    private var statusColor: Color {
        switch access {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .info: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body.weight(.medium))
                    if access != .info {
                        EarshotStatusDot(statusColor, size: 7)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let actionTitle, let action, access != .granted {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pairing

/// Large pairing code with a live countdown and a regenerate button.
struct EarshotPairingCodeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let code = model.pairing.code
            let remaining = max(0, Int(model.pairing.codeExpiresAt.timeIntervalSince(context.date)))
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.grouped(code))
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityLabel("Pairing code \(code.map { String($0) }.joined(separator: " "))")
                HStack(spacing: 10) {
                    Text(remaining > 0 ? "New code in \(String(format: "%d:%02d", remaining / 60, remaining % 60))"
                                       : "Refreshing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button {
                        model.regeneratePairingCode()
                    } label: {
                        Label("New Code", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
    }

    private static func grouped(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}

/// The server addresses to type on the watch, with copy buttons.
struct EarshotServerAddressList: View {
    @EnvironmentObject private var model: AppModel
    @State private var addresses: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if addresses.isEmpty {
                Label("No network connection found. Connect this Mac to the same Wi-Fi as your watch.",
                      systemImage: "wifi.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(addresses, id: \.self) { address in
                let url = "http://\(address):\(model.server.port)"
                HStack(spacing: 8) {
                    Text(url)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                        model.showBanner(.success, "Copied \(url)")
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy address")
                }
            }
        }
        .task {
            while !Task.isCancelled {
                let current = NetworkInfo.localIPv4Addresses()
                if current != addresses { addresses = current }
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
}

// MARK: - Markdown

/// Renders the subset of Markdown the AI produces: headings, bullet / numbered /
/// task lists, quotes, rules and paragraphs, with inline emphasis, code and links.
struct EarshotMarkdownView: View {
    private let blocks: [EarshotMarkdownBlock]

    init(_ markdown: String) {
        self.blocks = EarshotMarkdownBlock.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(blocks) { block in
                EarshotMarkdownBlockView(block: block)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EarshotMarkdownBlock: Identifiable, Hashable {
    enum Kind: Hashable {
        case heading(Int)
        case bullet(Int)
        case numbered(String)
        case task(Bool)
        case quote
        case rule
        case paragraph
        case spacer
    }

    let id: Int
    let kind: Kind
    let text: String

    static func parse(_ markdown: String) -> [EarshotMarkdownBlock] {
        var blocks: [EarshotMarkdownBlock] = []
        var lastWasSpacer = true
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for rawLine in lines {
            let indent = rawLine.prefix(while: { $0 == " " || $0 == "\t" }).count
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let kind: Kind
            var text = line
            if line.isEmpty {
                if lastWasSpacer { continue }
                kind = .spacer
            } else if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                kind = .heading(min(max(level, 1), 4))
            } else if line == "---" || line == "***" || line == "___" {
                kind = .rule
            } else if line.hasPrefix("- [ ] ") || line.hasPrefix("* [ ] ") {
                text = String(line.dropFirst(6))
                kind = .task(false)
            } else if line.lowercased().hasPrefix("- [x] ") || line.lowercased().hasPrefix("* [x] ") {
                text = String(line.dropFirst(6))
                kind = .task(true)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                text = String(line.dropFirst(2))
                kind = .bullet(min(indent / 2, 3))
            } else if line.hasPrefix(">") {
                text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                kind = .quote
            } else if let marker = numberedMarker(line) {
                text = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                kind = .numbered(String(marker.dropLast()))
            } else {
                kind = .paragraph
            }
            lastWasSpacer = (kind == .spacer)
            blocks.append(EarshotMarkdownBlock(id: blocks.count, kind: kind, text: text))
        }
        if let last = blocks.last, last.kind == .spacer {
            blocks.removeLast()
        }
        return blocks
    }

    /// "12." for "12. Something", nil otherwise.
    private static func numberedMarker(_ line: String) -> String? {
        let digits = line.prefix(while: { $0.isNumber })
        guard !digits.isEmpty, digits.count <= 3 else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return String(digits) + "."
    }

    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let parsed = try? AttributedString(markdown: text, options: options) {
            return parsed
        }
        return AttributedString(text)
    }
}

struct EarshotMarkdownBlockView: View {
    let block: EarshotMarkdownBlock

    var body: some View {
        switch block.kind {
        case .heading(let level):
            Text(EarshotMarkdownBlock.inline(block.text))
                .font(Self.headingFont(level))
                .padding(.top, level <= 2 ? 10 : 6)
                .padding(.bottom, 2)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let depth):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(depth == 0 ? "•" : "◦")
                    .foregroundStyle(.secondary)
                Text(EarshotMarkdownBlock.inline(block.text))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(depth) * 16 + 4)
        case .numbered(let number):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(EarshotMarkdownBlock.inline(block.text))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        case .task(let done):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: done ? "checkmark.square" : "square")
                    .foregroundStyle(done ? Color.green : Color.secondary)
                Text(EarshotMarkdownBlock.inline(block.text))
                    .strikethrough(done)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        case .quote:
            Text(EarshotMarkdownBlock.inline(block.text))
                .italic()
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 3)
                }
                .fixedSize(horizontal: false, vertical: true)
        case .rule:
            Divider()
                .padding(.vertical, 6)
        case .paragraph:
            Text(EarshotMarkdownBlock.inline(block.text))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        case .spacer:
            Color.clear
                .frame(height: 4)
        }
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title.weight(.bold)
        case 2: return .title2.weight(.semibold)
        case 3: return .title3.weight(.semibold)
        default: return .headline
        }
    }
}
