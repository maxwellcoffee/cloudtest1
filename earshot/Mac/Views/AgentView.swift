//  AgentView.swift
//  The Mac agent: give it a task, watch its steps (with screenshots) live,
//  cancel it, and browse past runs.

import SwiftUI
import AppKit

struct EarshotAgentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        AgentScreen(agent: model.agent, store: model.settings)
            .navigationTitle("Agent")
    }
}

private struct AgentScreen: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var agent: ComputerAgent
    @ObservedObject var store: SettingsStore
    @State var taskText = ""
    @State var selectedRunID: String? = nil

    /// Current run first, then history without duplicates.
    private var allRuns: [AgentRun] {
        var result: [AgentRun] = []
        if let current = agent.current {
            result.append(current)
        }
        for run in agent.runs where run.id != agent.current?.id {
            result.append(run)
        }
        return result
    }

    private var displayedRun: AgentRun? {
        if let id = selectedRunID, let run = allRuns.first(where: { $0.id == id }) {
            return run
        }
        return allRuns.first
    }

    var body: some View {
        VStack(spacing: 0) {
            AgentComposer(agent: agent, store: store, taskText: $taskText) {
                let text = taskText
                taskText = ""
                selectedRunID = nil
                model.runAgent(task: text)
            }
            Divider()
            HStack(spacing: 0) {
                AgentHistoryList(runs: allRuns, selectedRunID: $selectedRunID, displayedID: displayedRun?.id)
                    .frame(width: 270)
                Divider()
                if let run = displayedRun {
                    AgentRunDetail(run: run, isCurrent: run.id == agent.current?.id && agent.isRunning) {
                        agent.cancel()
                    }
                } else {
                    ContentUnavailableView {
                        Label("No tasks yet", systemImage: "sparkles")
                    } description: {
                        Text("Ask the agent to do something on this Mac: “Draft an email to Sam with today's decisions”, “Add my dentist appointment to the calendar”, or “Open the slides I mentioned this morning”. You can also send tasks from your watch.")
                    } actions: {
                        EmptyView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Composer

private struct AgentComposer: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var agent: ComputerAgent
    @ObservedObject var store: SettingsStore
    @Binding var taskText: String
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Describe a task for your Mac…", text: $taskText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit(runIfPossible)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                Button {
                    runIfPossible()
                } label: {
                    Label(agent.isRunning ? "Queue" : "Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(taskText.trimmed.isEmpty || !model.aiConfigured)
                if agent.isRunning {
                    Button(role: .destructive) {
                        agent.cancel()
                    } label: {
                        Label("Cancel", systemImage: "stop.fill")
                    }
                }
            }
            HStack(spacing: 16) {
                Toggle("Allow computer use", isOn: $store.settings.computerUseEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Let the agent see the screen and use the mouse and keyboard. Risky steps still ask you first.")
                if store.settings.computerUseEnabled {
                    TimelineView(.periodic(from: .now, by: 3)) { _ in
                        HStack(spacing: 12) {
                            PermissionPill(title: "Accessibility", granted: ComputerControl.hasAccessibility) {
                                ComputerControl.requestAccessibility()
                            }
                            PermissionPill(title: "Screen Recording", granted: ComputerControl.hasScreenRecording) {
                                ComputerControl.requestScreenRecording()
                            }
                        }
                    }
                }
                Spacer()
                if model.agentQueueDepth > 1 {
                    Text("\(model.agentQueueDepth - 1) more queued")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Up to \(store.settings.agentMaxSteps) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !model.aiConfigured {
                Text("The agent needs a Claude API key. Add one in Settings → AI.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
    }

    private func runIfPossible() {
        guard !taskText.trimmed.isEmpty, model.aiConfigured else { return }
        onRun()
    }
}

private struct PermissionPill: View {
    let title: String
    let granted: Bool
    let request: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            EarshotStatusDot(granted ? .green : .orange, size: 7)
            Text(title)
                .font(.caption)
            if !granted {
                Button("Allow…", action: request)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
        .help(granted ? "\(title) is allowed." : "\(title) is needed for computer use.")
    }
}

// MARK: - History

private enum AgentText {
    static func statusLabel(_ status: AgentRunStatus) -> String {
        switch status {
        case .running: return "Running"
        case .done: return "Done"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    static func statusColor(_ status: AgentRunStatus) -> Color {
        switch status {
        case .running: return .orange
        case .done: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    static func originLabel(_ origin: AgentOrigin) -> String {
        switch origin {
        case .mac: return "From this Mac"
        case .watch: return "From your watch"
        case .action: return "Suggested action"
        }
    }

    static func originSymbol(_ origin: AgentOrigin) -> String {
        switch origin {
        case .mac: return "desktopcomputer"
        case .watch: return "applewatch"
        case .action: return "sparkles"
        }
    }

    static func stepSymbol(_ kind: AgentStepKind) -> String {
        switch kind {
        case .note: return "text.bubble"
        case .toolCall: return "wrench.and.screwdriver"
        case .toolResult: return "arrow.turn.down.right"
        case .screenshot: return "camera.viewfinder"
        case .approval: return "hand.raised"
        case .error: return "exclamationmark.triangle"
        case .final: return "checkmark.seal"
        }
    }

    static func stepColor(_ kind: AgentStepKind) -> Color {
        switch kind {
        case .note: return .secondary
        case .toolCall: return .blue
        case .toolResult: return .teal
        case .screenshot: return .indigo
        case .approval: return .orange
        case .error: return .red
        case .final: return .green
        }
    }
}

private struct AgentHistoryList: View {
    let runs: [AgentRun]
    @Binding var selectedRunID: String?
    let displayedID: String?

    var body: some View {
        List(selection: $selectedRunID) {
            ForEach(runs) { run in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: AgentText.originSymbol(run.origin))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.task)
                            .font(.callout.weight(run.id == displayedID ? .semibold : .regular))
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            EarshotStatusDot(AgentText.statusColor(run.status), size: 6)
                            Text(AgentText.statusLabel(run.status))
                            Text("·")
                            Text(run.startedAt.shortText)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
                .tag(run.id)
            }
        }
        .listStyle(.inset)
        .overlay {
            if runs.isEmpty {
                Text("No runs yet")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Run detail

private struct AgentRunDetail: View {
    let run: AgentRun
    let isCurrent: Bool
    let onCancel: () -> Void

    private static let bottomID = "agent-steps-bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if !run.finalText.trimmed.isEmpty && run.status != .running {
                        EarshotCard {
                            EarshotMarkdownView(run.finalText)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Steps")
                            .font(.headline)
                        if run.steps.isEmpty {
                            Text(isCurrent ? "Starting…" : "No steps were recorded.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(run.steps) { step in
                            AgentStepRow(step: step)
                                .id(step.id)
                        }
                        if isCurrent {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Working…")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomID)
                }
                .padding(24)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: run.steps.count) {
                if isCurrent {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(Self.bottomID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(run.task)
                    .font(.title3.weight(.semibold))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if isCurrent {
                    Button(role: .destructive, action: onCancel) {
                        Label("Cancel", systemImage: "stop.fill")
                    }
                }
            }
            HStack(spacing: 8) {
                EarshotChip(AgentText.statusLabel(run.status), tint: AgentText.statusColor(run.status))
                EarshotChip(AgentText.originLabel(run.origin), symbol: AgentText.originSymbol(run.origin))
                Text(run.startedAt.shortText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let ended = run.endedAt {
                    Text("· took \(EarshotFormat.duration(ended.timeIntervalSince(run.startedAt)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("· \(run.steps.count) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AgentStepRow: View {
    let step: AgentStep
    @State var expanded = false
    @State var zoomed = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: AgentText.stepSymbol(step.kind))
                .foregroundStyle(AgentText.stepColor(step.kind))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(step.title)
                        .font(.callout.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(step.at.timeText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let detail = step.detail.nilIfEmpty {
                    Text(detail)
                        .font(.system(.caption, design: step.kind == .toolCall || step.kind == .toolResult ? Font.Design.monospaced : Font.Design.default))
                        .foregroundStyle(.secondary)
                        .lineLimit(expanded ? nil : 6)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    if detail.count > 400 || detail.components(separatedBy: "\n").count > 6 {
                        Button(expanded ? "Show less" : "Show more") {
                            expanded.toggle()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
                if let data = step.imagePNG, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .scaledToFit()
                        .frame(maxWidth: 380, maxHeight: 240, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(EarshotPalette.cardBorder, lineWidth: 1)
                        )
                        .onTapGesture {
                            zoomed = true
                        }
                        .help("Click to enlarge")
                        .popover(isPresented: $zoomed) {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 960)
                                .padding(8)
                        }
                }
            }
        }
        .padding(10)
        .background(step.kind == .error ? Color.red.opacity(0.06) : EarshotPalette.cardBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
