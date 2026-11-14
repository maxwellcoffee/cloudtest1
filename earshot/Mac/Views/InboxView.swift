//  InboxView.swift
//  Everything waiting for the user: agent approvals, suggested actions,
//  questions from the companion (answerable on the Mac), and history.

import SwiftUI
import AppKit

struct EarshotInboxView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        InboxContent(approvals: model.approvals)
            .navigationTitle("Inbox")
    }
}

private struct InboxContent: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var approvals: ApprovalCenter
    @State var editing: ProposedAction? = nil

    var body: some View {
        let proposed = model.proposedActions
        let active = model.activeActions
        let questions = model.openQuestions
        let nothingWaiting = approvals.pending.isEmpty && proposed.isEmpty && questions.isEmpty && active.isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if nothingWaiting {
                    InboxAllClear()
                }
                if !approvals.pending.isEmpty {
                    ApprovalsSection(requests: approvals.pending) { id, approved in
                        approvals.resolve(id: id, approved: approved)
                    }
                }
                if !active.isEmpty {
                    RunningActionsSection(actions: active)
                }
                if !proposed.isEmpty {
                    SuggestedActionsSection(actions: proposed) { action in
                        editing = action
                    }
                }
                if !questions.isEmpty {
                    QuestionsSection(prompts: questions)
                }
                HistorySection()
            }
            .padding(24)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $editing) { action in
            ActionEditorSheet(action: action) { edited in
                model.updateAction(edited)
            }
        }
    }
}

private struct InboxAllClear: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("You're all caught up")
                    .font(.title3.weight(.semibold))
                Text("Suggested actions, approvals and questions from Earshot show up here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Approvals

private struct ApprovalsSection: View {
    let requests: [ApprovalRequest]
    let onResolve: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EarshotSectionHeader("Needs your approval", symbol: "hand.raised", count: requests.count,
                                 subtitle: "The agent is waiting for you before it continues.")
            ForEach(requests) { request in
                EarshotCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(request.title)
                                .font(.headline)
                            Spacer()
                            EarshotRiskChip(request.risk)
                        }
                        if let detail = request.detail.nilIfEmpty {
                            Text(detail)
                                .font(.system(.callout, design: detail.contains("\n") ? Font.Design.monospaced : Font.Design.default))
                                .textSelection(.enabled)
                                .lineLimit(14)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 10) {
                            Button("Approve") {
                                onResolve(request.id, true)
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Deny", role: .destructive) {
                                onResolve(request.id, false)
                            }
                            Spacer()
                            TimelineView(.periodic(from: .now, by: 30)) { _ in
                                Text("Asked \(request.createdAt.relativeText)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if request.promptID != nil {
                                Image(systemName: "applewatch")
                                    .foregroundStyle(.secondary)
                                    .help("Also sent to your watch")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Actions

private struct ActionPayloadLine: Identifiable {
    let id: String
    let value: String
}

private enum ActionText {
    static func lines(for action: ProposedAction) -> [ActionPayloadLine] {
        let payload = action.payload
        var lines: [ActionPayloadLine] = []
        func add(_ label: String, _ value: String?) {
            if let value = value?.nilIfEmpty {
                lines.append(ActionPayloadLine(id: label, value: value))
            }
        }
        switch action.kind {
        case .reminder:
            add("Due", EarshotFormat.payloadDate(payload.dueISO))
            add("Notes", payload.notes)
        case .calendarEvent:
            add("Starts", EarshotFormat.payloadDate(payload.startISO))
            add("Ends", EarshotFormat.payloadDate(payload.endISO))
            add("Location", payload.location)
            add("Notes", payload.notes)
        case .note:
            add("Note", payload.body ?? payload.notes)
        case .emailDraft:
            add("To", payload.recipient)
            add("Subject", payload.subject)
            add("Body", payload.body)
        case .openURL:
            add("Link", payload.url)
        case .openApp:
            add("App", payload.appName)
        case .shortcut:
            add("Shortcut", payload.shortcutName)
            add("Input", payload.input)
        case .appleScript:
            add("Script", payload.script)
        case .agentTask:
            add("Task", payload.task)
        }
        return lines
    }

    static func statusLabel(_ status: ActionStatus) -> String {
        switch status {
        case .proposed: return "Suggested"
        case .approved: return "Approved"
        case .running: return "Running"
        case .done: return "Done"
        case .failed: return "Failed"
        case .rejected: return "Dismissed"
        }
    }
}

private struct ActionSummary: View {
    let action: ProposedAction
    var lineLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: action.kind.symbol)
                    .foregroundStyle(.tint)
                Text(action.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                EarshotChip(action.kind.label, tint: .secondary)
                EarshotRiskChip(action.kind.risk)
            }
            if let rationale = action.rationale.nilIfEmpty {
                Text(rationale)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let lines = ActionText.lines(for: action)
            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(line.id)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .trailing)
                            Text(line.value)
                                .font(.callout)
                                .lineLimit(lineLimit)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct RunningActionsSection: View {
    let actions: [ProposedAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EarshotSectionHeader("In progress", symbol: "gearshape.2", count: actions.count)
            ForEach(actions) { action in
                EarshotCard {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        ActionSummary(action: action, lineLimit: 2)
                    }
                }
            }
        }
    }
}

private struct SuggestedActionsSection: View {
    @EnvironmentObject var model: AppModel
    let actions: [ProposedAction]
    let onEdit: (ProposedAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EarshotSectionHeader("Suggested actions", symbol: "sparkles", count: actions.count,
                                 subtitle: "Things Earshot can do for you on this Mac. Nothing runs until you approve it.")
            ForEach(actions) { action in
                EarshotCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ActionSummary(action: action)
                        HStack(spacing: 10) {
                            Button {
                                model.approveAndRun(action)
                            } label: {
                                Label("Approve & Run", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.runningActionIDs.contains(action.id))
                            Button("Edit…") {
                                onEdit(action)
                            }
                            Button("Dismiss") {
                                model.reject(action)
                            }
                            Spacer()
                            Text(action.createdAt.shortText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Questions

private struct QuestionsSection: View {
    let prompts: [StoredPrompt]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EarshotSectionHeader("Questions for you", symbol: "bubble.left.and.exclamationmark.bubble.right",
                                 count: prompts.count,
                                 subtitle: "Earshot asks on your watch at good moments. You can also answer here.")
            ForEach(prompts) { prompt in
                PromptCard(prompt: prompt)
            }
        }
    }
}

private struct PromptCard: View {
    @EnvironmentObject var model: AppModel
    let prompt: StoredPrompt
    @State var reply = ""

    private var statusText: String {
        switch prompt.status {
        case .queued:
            if let notBefore = prompt.notBefore, notBefore > Date() {
                return "Waiting until \(notBefore.shortText)"
            }
            return "Waiting for a good moment"
        case .pending: return "Sent to your watch"
        case .delivered: return "Shown on your watch"
        case .awaitingVoice: return "Waiting for your spoken answer"
        case .answered: return "Answered"
        case .dismissed: return "Dismissed"
        case .expired: return "Expired"
        }
    }

    private var statusColor: Color {
        switch prompt.status {
        case .queued: return .secondary
        case .pending, .delivered: return .blue
        case .awaitingVoice: return .purple
        case .answered: return .green
        case .dismissed, .expired: return .secondary
        }
    }

    var body: some View {
        EarshotCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    EarshotChip(prompt.kind == .nudge ? "Nudge" : "Question",
                                symbol: prompt.kind == .nudge ? "bell" : "questionmark.bubble",
                                tint: prompt.kind == .nudge ? .orange : .indigo)
                    EarshotChip(statusText, tint: statusColor)
                    if prompt.priority >= 4 {
                        EarshotChip("Important", symbol: "exclamationmark", tint: .red)
                    }
                    Spacer()
                    Text(prompt.createdAt.shortText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(prompt.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let message = prompt.body.nilIfEmpty, message != prompt.title.trimmed {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let rationale = prompt.rationale.nilIfEmpty {
                    Label(rationale, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !prompt.choices.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(prompt.choices) { choice in
                            Button(choice.title) {
                                model.answer(prompt, choiceID: choice.id)
                            }
                        }
                    }
                }
                if prompt.allowsFreeText {
                    HStack(spacing: 8) {
                        TextField("Type an answer…", text: $reply)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(sendReply)
                        Button("Send", action: sendReply)
                            .disabled(reply.trimmed.isEmpty)
                    }
                }
                HStack(spacing: 12) {
                    if prompt.status == .queued {
                        Button {
                            model.sendToWatchNow(prompt)
                        } label: {
                            Label("Send to Watch Now", systemImage: "applewatch.radiowaves.left.and.right")
                        }
                    }
                    Button("Ask Later") {
                        model.snooze(prompt)
                    }
                    Button("Not Now") {
                        model.dismiss(prompt)
                    }
                    Spacer()
                }
                .buttonStyle(.borderless)
                .font(.callout)
            }
        }
    }

    private func sendReply() {
        guard let text = reply.nilIfEmpty else { return }
        model.answer(prompt, text: text)
        reply = ""
    }
}

// MARK: - History

private struct HistorySection: View {
    @EnvironmentObject var model: AppModel
    @State var showAllPrompts = false
    @State var showAllActions = false

    private static let finishedPromptStatuses: Set<PromptStatus> = [.answered, .dismissed, .expired]
    private static let finishedActionStatuses: Set<ActionStatus> = [.done, .failed, .rejected]

    var body: some View {
        let answered = model.prompts.filter { prompt in
            prompt.kind != .approval && HistorySection.finishedPromptStatuses.contains(prompt.status)
        }
        let finished = model.actions.filter { action in
            HistorySection.finishedActionStatuses.contains(action.status)
        }
        let sentToWatch = model.prompts.filter { prompt in
            (prompt.kind == .answer || prompt.kind == .digest || prompt.kind == .info)
                && prompt.status != .queued
        }
        if !answered.isEmpty || !finished.isEmpty || !sentToWatch.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                EarshotSectionHeader("History", symbol: "clock.arrow.circlepath")
                if !answered.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Questions")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(showAllPrompts ? answered : Array(answered.prefix(8))) { prompt in
                            AnsweredPromptRow(prompt: prompt)
                        }
                        if answered.count > 8 {
                            Button(showAllPrompts ? "Show Less" : "Show All \(answered.count)") {
                                showAllPrompts.toggle()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                if !finished.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actions")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(showAllActions ? finished : Array(finished.prefix(8))) { action in
                            FinishedActionRow(action: action)
                        }
                        if finished.count > 8 {
                            Button(showAllActions ? "Show Less" : "Show All \(finished.count)") {
                                showAllActions.toggle()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                if !sentToWatch.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sent to your watch")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(sentToWatch.prefix(6))) { prompt in
                            SentPromptRow(prompt: prompt)
                        }
                    }
                }
            }
        }
    }
}

private struct AnsweredPromptRow: View {
    let prompt: StoredPrompt

    private var answerText: String {
        switch prompt.status {
        case .dismissed: return "Not now"
        case .expired: return "Expired without an answer"
        default:
            var parts: [String] = []
            if let choiceID = prompt.answerChoiceID,
               let choice = prompt.choices.first(where: { $0.id == choiceID }) {
                parts.append(choice.title)
            }
            if let text = prompt.answerText?.nilIfEmpty {
                parts.append(text)
            }
            return parts.isEmpty ? "Answered" : parts.joined(separator: " · ")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: prompt.status == .answered ? "checkmark.bubble" : "bubble.left")
                .foregroundStyle(prompt.status == .answered ? Color.green : Color.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.callout.weight(.medium))
                Text(answerText)
                    .font(.callout)
                    .foregroundStyle(prompt.status == .answered ? Color.primary : Color.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text((prompt.answeredAt ?? prompt.createdAt).shortText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct FinishedActionRow: View {
    @EnvironmentObject var model: AppModel
    let action: ProposedAction

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: action.kind.symbol)
                .foregroundStyle(EarshotPalette.color(for: action.status))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(action.title)
                        .font(.callout.weight(.medium))
                    EarshotChip(ActionText.statusLabel(action.status), tint: EarshotPalette.color(for: action.status))
                }
                if let result = action.result?.nilIfEmpty {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text((action.executedAt ?? action.createdAt).shortText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                switch action.status {
                case .failed:
                    Button("Retry") {
                        model.approveAndRun(action)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                case .rejected:
                    Button("Restore") {
                        model.restore(action)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                default:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SentPromptRow: View {
    @EnvironmentObject var model: AppModel
    let prompt: StoredPrompt

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: prompt.kind == .digest ? "doc.text" : "applewatch")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.callout.weight(.medium))
                Text(prompt.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Text((prompt.releasedAt ?? prompt.createdAt).shortText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor

private struct ActionEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (ProposedAction) -> Void
    @State var draft: ProposedAction

    init(action: ProposedAction, onSave: @escaping (ProposedAction) -> Void) {
        self.onSave = onSave
        _draft = State(initialValue: action)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: draft.kind.symbol)
                    .foregroundStyle(.tint)
                Text("Edit \(draft.kind.label)")
                    .font(.headline)
            }
            Form {
                TextField("Title", text: $draft.title)
                fields
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    var saved = draft
                    saved.title = saved.title.trimmed
                    onSave(saved)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.title.trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 460)
    }

    @ViewBuilder
    private var fields: some View {
        switch draft.kind {
        case .reminder:
            dateField("Due", \.dueISO)
            textField("Notes", \.notes, multiline: true)
        case .calendarEvent:
            dateField("Starts", \.startISO)
            dateField("Ends", \.endISO)
            textField("Location", \.location)
            textField("Notes", \.notes, multiline: true)
        case .note:
            textField("Note", \.body, multiline: true)
        case .emailDraft:
            textField("To", \.recipient)
            textField("Subject", \.subject)
            textField("Body", \.body, multiline: true)
        case .openURL:
            textField("Link", \.url)
        case .openApp:
            textField("App name", \.appName)
        case .shortcut:
            textField("Shortcut name", \.shortcutName)
            textField("Input", \.input, multiline: true)
        case .appleScript:
            textField("Script", \.script, multiline: true)
                .font(.system(.body, design: .monospaced))
        case .agentTask:
            textField("Task", \.task, multiline: true)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ActionPayload, String?>) -> Binding<String> {
        Binding(
            get: { draft.payload[keyPath: keyPath] ?? "" },
            set: { newValue in
                draft.payload[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
            }
        )
    }

    @ViewBuilder
    private func textField(_ title: String, _ keyPath: WritableKeyPath<ActionPayload, String?>,
                           multiline: Bool = false) -> some View {
        if multiline {
            TextField(title, text: binding(keyPath), axis: .vertical)
                .lineLimit(3...10)
        } else {
            TextField(title, text: binding(keyPath))
        }
    }

    @ViewBuilder
    private func dateField(_ title: String, _ keyPath: WritableKeyPath<ActionPayload, String?>) -> some View {
        let raw = draft.payload[keyPath: keyPath] ?? ""
        VStack(alignment: .leading, spacing: 3) {
            TextField(title, text: binding(keyPath), prompt: Text("2026-11-14T15:00 or 2026-11-14"))
            if let value = raw.nilIfEmpty {
                if let parsed = DateParsing.parse(value) {
                    Text(DateParsing.isDateOnly(value) ? "All day, \(EarshotFormat.payloadDate(value) ?? value)" : parsed.shortText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not a date Earshot understands.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
