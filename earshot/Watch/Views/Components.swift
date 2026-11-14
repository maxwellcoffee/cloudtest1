//  Components.swift
//  Earshot (watchOS)
//
//  Small reusable views, styles and formatters.

import SwiftUI

// MARK: - Formatting

enum EarshotFormat {
    /// 83 → "1:23", 3725 → "1:02:05".
    static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return "\(hours):\(pad(minutes)):\(pad(secs))" }
        return "\(minutes):\(pad(secs))"
    }

    /// 11_520 → "3h 12m", 600 → "10m", 42 → "42s".
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0s" }
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    static func minutes(_ minutes: Double) -> String {
        duration(minutes * 60)
    }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    /// "just now", "4m ago", "2h ago", "3d ago", or "never".
    static func relative(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "never" }
        let seconds = now.timeIntervalSince(date)
        if seconds < 45 { return "just now" }
        if seconds < 3600 { return "\(max(1, Int((seconds / 60).rounded())))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86_400))d ago"
    }

    /// Short local time, e.g. "3:45 PM".
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

// MARK: - Prompt styling

enum PromptStyle {
    static func symbol(_ kind: PromptKind) -> String {
        switch kind {
        case .question: return "questionmark.bubble.fill"
        case .approval: return "checkmark.shield.fill"
        case .answer: return "text.bubble.fill"
        case .nudge: return "bell.fill"
        case .digest: return "doc.text.fill"
        case .info: return "info.circle.fill"
        }
    }

    static func tint(_ kind: PromptKind) -> Color {
        switch kind {
        case .question: return .blue
        case .approval: return .orange
        case .answer: return .green
        case .nudge: return .yellow
        case .digest: return .purple
        case .info: return .gray
        }
    }

    static func label(_ kind: PromptKind) -> String {
        switch kind {
        case .question: return "Question"
        case .approval: return "Approval needed"
        case .answer: return "Answer"
        case .nudge: return "Reminder"
        case .digest: return "Summary ready"
        case .info: return "Info"
        }
    }
}

// MARK: - Views

/// Horizontal input-level bar (dBFS -60…0 mapped to 0…1).
struct LevelMeter: View {
    let level: Float
    var active: Bool = true

    var body: some View {
        GeometryReader { geometry in
            let fraction = CGFloat(active ? LevelMeter.normalized(level) : 0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(fraction > 0.85 ? Color.orange : Color.green)
                    .frame(width: max(4, geometry.size.width * fraction))
            }
        }
        .frame(height: 6)
        .animation(.linear(duration: 0.2), value: level)
        .accessibilityLabel("Input level")
    }

    static func normalized(_ db: Float) -> Float {
        min(1, max(0, (db + 60) / 60))
    }
}

/// A compact number with an icon and a caption.
struct StatTile: View {
    let value: String
    let label: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(tint)
            Text(verbatim: value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(verbatim: label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Red count pill.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(verbatim: count > 99 ? "99+" : "\(count)")
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.red, in: Capsule())
    }
}

/// Round, tinted icon button with a generous tap target.
struct CircleIconButtonStyle: ButtonStyle {
    var tint: Color
    var size: CGFloat = 50

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(configuration.isPressed ? 0.45 : 0.25), in: Circle())
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.35)
    }
}

/// Icon + small caption under a round button.
struct CaptionedButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
            Text(verbatim: title)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// One-line status text with an optional symbol.
struct StatusText: View {
    let text: String
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(verbatim: text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .font(.footnote)
        .foregroundStyle(tint)
    }
}
