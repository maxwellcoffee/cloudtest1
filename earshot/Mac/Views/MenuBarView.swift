//  MenuBarView.swift
//  Content of the menu bar extra: status at a glance and quick actions.

import SwiftUI
import AppKit

struct EarshotMenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: model.serverRunning ? "waveform" : "waveform.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(model.serverRunning ? Color.accentColor : Color.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Earshot")
                        .font(.headline)
                    Text(model.pipelineStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 7) {
                MenuStatusLine(symbol: "server.rack",
                               text: model.serverRunning ? "Server listening on port \(String(model.server.port))"
                                                         : "Server stopped: \(model.serverError ?? "not running")",
                               tint: model.serverRunning ? .green : .red)
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    MenuStatusLine(symbol: "applewatch",
                                   text: Self.watchText(model: model, now: context.date),
                                   tint: Self.watchTint(model.lastWatchContact, now: context.date))
                }
                MenuStatusLine(symbol: "text.bubble",
                               text: "\(EarshotFormat.count(model.todayWordCount)) words today",
                               tint: .accentColor)
                MenuInboxLine(approvals: model.approvals)
                if model.isAnalyzing {
                    MenuStatusLine(symbol: "sparkles", text: "Analyzing…", tint: .purple)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                MenuActionButton(title: "Open Earshot", symbol: "macwindow") {
                    openMainWindow()
                }
                MenuActionButton(title: "Analyze Now", symbol: "sparkles", disabled: model.isAnalyzing) {
                    model.analyzeNow()
                }
                MenuActionButton(title: "Today's Digest", symbol: "doc.text", disabled: model.isGeneratingDigest) {
                    model.openTodaysDigest()
                    openMainWindow()
                }
                MenuMicButton(mic: model.micRecorder)
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                MenuActionButton(title: "Settings…", symbol: "gearshape") {
                    NSApp.activate()
                    openSettings()
                }
                MenuActionButton(title: "Quit Earshot", symbol: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func openMainWindow() {
        NSApp.activate()
        let existing = NSApp.windows.first { window in
            window.identifier?.rawValue.hasPrefix("main") == true && window.canBecomeMain
        }
        if let window = existing {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }

    private static func watchText(model: AppModel, now: Date) -> String {
        guard model.hasPairedWatch else { return "No watch paired" }
        guard let lastSeen = model.lastWatchContact else { return "Watch hasn't synced yet" }
        if now.timeIntervalSince(lastSeen) < 60 { return "Watch synced just now" }
        return "Watch synced \(lastSeen.relativeText)"
    }

    private static func watchTint(_ lastSeen: Date?, now: Date) -> Color {
        guard let lastSeen else { return .secondary }
        return now.timeIntervalSince(lastSeen) < 180 ? .green : .orange
    }
}

private struct MenuStatusLine: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(.callout)
                .lineLimit(2)
        }
    }
}

private struct MenuInboxLine: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var approvals: ApprovalCenter

    var body: some View {
        let count = approvals.pending.count + model.proposedActions.count + model.unansweredPromptCount
        if count > 0 {
            Button {
                model.sidebarSelection = .inbox
                NSApp.activate()
            } label: {
                MenuStatusLine(symbol: "tray.full",
                               text: count == 1 ? "1 item needs you" : "\(count) items need you",
                               tint: .orange)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct MenuActionButton: View {
    let title: String
    let symbol: String
    var disabled = false
    let action: () -> Void
    @State var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .frame(width: 18)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(hovering && !disabled ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .onHover { inside in
            hovering = inside
        }
    }
}

private struct MenuMicButton: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var mic: MacMicRecorder

    var body: some View {
        HStack(spacing: 8) {
            MenuActionButton(title: mic.isRecording ? "Stop Mac Microphone" : "Use Mac Microphone",
                             symbol: mic.isRecording ? "mic.slash" : "mic") {
                model.setMacMicEnabled(!mic.isRecording)
            }
            if mic.isRecording {
                EarshotLevelMeter(level: mic.level, active: true)
                    .frame(width: 70)
            }
        }
    }
}
