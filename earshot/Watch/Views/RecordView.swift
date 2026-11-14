//  RecordView.swift
//  Earshot (watchOS)
//
//  The main page: big record/stop button, level, today's total, upload/sync
//  status, and quick actions (Mark, Pause, Ask/Do).

import SwiftUI

struct RecordView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var recorder: AudioCapture
    @EnvironmentObject private var queue: SegmentQueue
    @EnvironmentObject private var prompts: PromptCenter

    @State private var showPauseOptions = false
    @State private var showStopOptions = false
    @State private var markedAt: Date? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if store.pairingStatus != .paired {
                    pairButton
                }

                RecordButton(state: recorder.state,
                             elapsed: recorder.segmentElapsed,
                             action: primaryAction)

                Text(verbatim: "Today \(EarshotFormat.duration(recorder.todayTotalSeconds))")
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()

                LevelMeter(level: recorder.level, active: recorder.isRecording)
                    .padding(.horizontal, 8)

                stateNotice

                TimelineView(.everyMinute) { context in
                    StatusText(text: statusLine(now: context.date), systemImage: statusSymbol, tint: statusTint)
                }

                controls
                    .padding(.top, 2)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Earshot")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if prompts.unansweredCount > 0 {
                    Button {
                        store.selectedTab = .inbox
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "tray.full.fill")
                            CountBadge(count: prompts.unansweredCount)
                        }
                    }
                    .accessibilityLabel("Inbox, \(prompts.unansweredCount) waiting")
                }
            }
        }
        .containerBackground(backgroundTint.gradient, for: .tabView)
        .overlay(alignment: .center) {
            if markedAt != nil {
                Label("Marked", systemImage: "bookmark.fill")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: markedAt)
        .confirmationDialog(Text("Pause recording"), isPresented: $showPauseOptions, titleVisibility: .visible) {
            Button("15 minutes") { recorder.pause(for: 15 * 60) }
            Button("1 hour") { recorder.pause(for: 60 * 60) }
            Button("Until I resume") { recorder.pause(for: nil) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(Text("Stop recording?"), isPresented: $showStopOptions, titleVisibility: .visible) {
            Button("Pause 15 minutes") { recorder.pause(for: 15 * 60) }
            Button("Stop recording", role: .destructive) { recorder.stop() }
            Button("Keep recording", role: .cancel) {}
        }
    }

    // MARK: Pieces

    private var pairButton: some View {
        Button {
            store.selectedTab = .settings
        } label: {
            Label(pairTitle, systemImage: "link.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    private var pairTitle: String {
        store.pairingStatus == .needsRepair ? "Pair again" : "Pair with your Mac"
    }

    @ViewBuilder
    private var stateNotice: some View {
        switch recorder.state {
        case .error(let message):
            StatusText(text: message, systemImage: "exclamationmark.triangle.fill", tint: .yellow)
        case .interrupted:
            StatusText(text: "Paused by a call or Siri. Tap to resume.", systemImage: "phone.fill", tint: .yellow)
        case .paused(let until):
            StatusText(text: pauseText(until), systemImage: "pause.circle.fill", tint: .orange)
        case .idle, .recording:
            if let notice = recorder.notice {
                StatusText(text: notice, systemImage: "exclamationmark.circle", tint: .yellow)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                store.markMoment()
                markedAt = Date()
                let stamp = markedAt
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    if markedAt == stamp { markedAt = nil }
                }
            } label: {
                CaptionedButtonLabel(title: "Mark", systemImage: "bookmark.fill")
            }
            .buttonStyle(CircleIconButtonStyle(tint: .yellow))
            .disabled(!recorder.isRecording)
            .modifier(DoubleTapPrimaryAction())
            .accessibilityLabel("Mark this moment")

            if recorder.isPrivacyPaused {
                Button {
                    Task { await recorder.resume() }
                } label: {
                    CaptionedButtonLabel(title: "Resume", systemImage: "play.fill")
                }
                .buttonStyle(CircleIconButtonStyle(tint: .green))
                .accessibilityLabel("Resume recording")
            } else {
                Button {
                    showPauseOptions = true
                } label: {
                    CaptionedButtonLabel(title: "Pause", systemImage: "pause.fill")
                }
                .buttonStyle(CircleIconButtonStyle(tint: .orange))
                .disabled(!(recorder.isRecording || recorder.state == .interrupted))
                .accessibilityLabel("Privacy pause")
            }

            NavigationLink {
                RequestView()
            } label: {
                CaptionedButtonLabel(title: "Ask/Do", systemImage: "sparkles")
            }
            .buttonStyle(CircleIconButtonStyle(tint: .blue))
            .accessibilityLabel("Ask or tell your Mac")
        }
    }

    // MARK: Behaviour

    private func primaryAction() {
        switch recorder.state {
        case .recording:
            showStopOptions = true
        case .paused:
            Task { await recorder.resume() }
        case .idle, .interrupted, .error:
            Task { await recorder.start() }
        }
    }

    private func pauseText(_ until: Date?) -> String {
        guard let until else { return "Privacy pause until you resume." }
        if until.timeIntervalSinceNow <= 0 { return "Pause over. Tap to resume." }
        return "Privacy pause until \(EarshotFormat.time(until))."
    }

    private var backgroundTint: Color {
        switch recorder.state {
        case .recording: return .red
        case .paused: return .orange
        case .interrupted, .error: return .yellow
        case .idle: return .gray
        }
    }

    private func statusLine(now: Date) -> String {
        var parts: [String] = []
        if queue.isUploading {
            parts.append("Uploading \(max(queue.queuedSegments, 1))")
        } else if queue.queuedSegments > 0 {
            parts.append("\(queue.queuedSegments) queued")
        }
        switch store.pairingStatus {
        case .unpaired:
            parts.append("Not paired")
        case .needsRepair:
            parts.append("Pair again")
        case .paired:
            if let error = store.lastSyncError ?? queue.lastError {
                parts.append(error)
            } else {
                parts.append("Synced \(EarshotFormat.relative(store.lastSyncAt, now: now))")
            }
            if let name = store.macName { parts.append(name) }
        }
        return parts.joined(separator: " · ")
    }

    private var statusSymbol: String? {
        if store.pairingStatus != .paired { return "link" }
        if queue.isUploading { return "arrow.up.circle" }
        if store.lastSyncError != nil || queue.lastError != nil { return "wifi.exclamationmark" }
        return "checkmark.circle"
    }

    private var statusTint: Color {
        if store.pairingStatus != .paired { return .secondary }
        if store.lastSyncError != nil || queue.lastError != nil { return .yellow }
        return .secondary
    }
}

// MARK: - Record button

private struct RecordButton: View {
    let state: RecorderState
    let elapsed: TimeInterval
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                PulsingRing(active: state == .recording, color: ringColor)
                Circle()
                    .fill(fillColor)
                    .padding(9)
                VStack(spacing: 2) {
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .bold))
                    Text(verbatim: title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(verbatim: subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
            }
            .frame(width: 118, height: 118)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var symbol: String {
        switch state {
        case .recording: return "stop.fill"
        case .paused: return "play.fill"
        case .interrupted: return "arrow.clockwise"
        case .error: return "exclamationmark.triangle.fill"
        case .idle: return "mic.fill"
        }
    }

    private var title: String {
        switch state {
        case .recording: return EarshotFormat.clock(elapsed)
        case .paused: return "Paused"
        case .interrupted: return "Resume"
        case .error: return "Retry"
        case .idle: return "Record"
        }
    }

    private var subtitle: String {
        switch state {
        case .recording: return "Tap to stop"
        case .paused: return "Tap to resume"
        case .interrupted: return "Tap to resume"
        case .error: return "Tap to try again"
        case .idle: return "Tap to start"
        }
    }

    private var ringColor: Color {
        switch state {
        case .recording: return .red
        case .paused: return .orange
        case .interrupted, .error: return .yellow
        case .idle: return .gray
        }
    }

    private var fillColor: Color {
        switch state {
        case .recording: return Color.red.opacity(0.85)
        case .paused: return Color.orange.opacity(0.7)
        case .interrupted, .error: return Color.yellow.opacity(0.55)
        case .idle: return Color.red.opacity(0.6)
        }
    }

    private var accessibilityText: String {
        switch state {
        case .recording: return "Recording, \(EarshotFormat.clock(elapsed)). Double tap to stop."
        case .paused: return "Paused. Double tap to resume."
        case .interrupted: return "Recording interrupted. Double tap to resume."
        case .error(let message): return "\(message) Double tap to try again."
        case .idle: return "Not recording. Double tap to start."
        }
    }
}

/// The red ring breathes while recording (static when the screen dims).
private struct PulsingRing: View {
    let active: Bool
    let color: Color

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !active || isLuminanceReduced)) { context in
            let animate = active && !isLuminanceReduced
            let time = context.date.timeIntervalSinceReferenceDate
            let phase = animate ? (sin(time * 2 * Double.pi / 1.6) + 1) / 2 : 0
            Circle()
                .stroke(color.opacity(0.45 + 0.45 * phase), lineWidth: 5 + 3 * phase)
                .scaleEffect(1 + 0.03 * phase)
                .padding(4)
        }
    }
}

/// On watchOS 11+, the double-tap gesture marks the moment.
private struct DoubleTapPrimaryAction: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(watchOS 11.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}
