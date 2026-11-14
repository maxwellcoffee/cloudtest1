//  PromptDetailView.swift
//  Earshot (watchOS)
//
//  Answering on the wrist: choices, Approve/Deny, a dictated reply, "Say it"
//  (a 20-second spoken answer the always-on recorder captures), Later, Not now.

import SwiftUI

struct PromptDetailView: View {
    let promptID: String

    @EnvironmentObject private var prompts: PromptCenter
    @EnvironmentObject private var recorder: AudioCapture
    @Environment(\.dismiss) private var dismiss

    @State private var reply = ""
    @State private var showVoice = false

    var body: some View {
        Group {
            if let item = prompts.item(id: promptID) {
                content(item)
            } else {
                ContentUnavailableView("Prompt gone", systemImage: "questionmark.bubble",
                                       description: Text("It expired or was answered on your Mac."))
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { prompts.markShown([promptID]) }
        .sheet(isPresented: $showVoice, onDismiss: {
            if let item = prompts.item(id: promptID), !item.isOpen { dismiss() }
        }) {
            VoiceAnswerSheet(promptID: promptID)
                .environmentObject(prompts)
                .environmentObject(recorder)
        }
    }

    private var navigationTitle: String {
        guard let item = prompts.item(id: promptID) else { return "Prompt" }
        return PromptStyle.label(item.prompt.kind)
    }

    // MARK: Content

    private func content(_ item: InboxPrompt) -> some View {
        let prompt = item.prompt
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: PromptStyle.symbol(prompt.kind))
                        .foregroundStyle(PromptStyle.tint(prompt.kind))
                    Text(verbatim: EarshotFormat.relative(prompt.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if prompt.priority >= 4 {
                        Text("Urgent")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }

                if !prompt.title.isEmpty {
                    Text(verbatim: prompt.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !prompt.body.isEmpty {
                    Text(verbatim: prompt.body)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if item.isOpen {
                    answerControls(prompt)
                } else {
                    answeredSummary(item)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func answerControls(_ prompt: WirePrompt) -> some View {
        if prompt.kind == .approval {
            approvalButtons(prompt)
        } else if !prompt.choices.isEmpty {
            ForEach(prompt.choices) { choice in
                Button {
                    send(.choice, choiceID: choice.id)
                } label: {
                    Text(verbatim: choice.title)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.bordered)
                .tint(PromptStyle.tint(prompt.kind))
            }
        }

        if prompt.allowsFreeText {
            TextField("Reply", text: $reply, prompt: Text("Reply…"))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .onSubmit { sendReply() }
            if !trimmedReply.isEmpty {
                Button {
                    sendReply()
                } label: {
                    Label("Send reply", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }

        if prompt.allowsVoice {
            Button {
                showVoice = true
            } label: {
                Label("Say it", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }

        // Approvals get neither: the Mac can't snooze them and reads a dismissal as Deny.
        // Going back leaves the request pending (it can still be decided on the Mac).
        if prompt.kind != .approval {
            HStack(spacing: 6) {
                Button {
                    send(.snoozed)
                } label: {
                    Text("Later").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    send(.dismissed)
                } label: {
                    Text(closeTitle(prompt)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func approvalButtons(_ prompt: WirePrompt) -> some View {
        let approve = prompt.choices.first(where: { $0.id == "approve" }) ?? PromptChoice(id: "approve", title: "Approve")
        let deny = prompt.choices.first(where: { $0.id == "deny" }) ?? PromptChoice(id: "deny", title: "Deny")
        Button {
            send(.choice, choiceID: approve.id)
        } label: {
            Label(approve.title, systemImage: "checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)

        Button {
            send(.choice, choiceID: deny.id)
        } label: {
            Label(deny.title, systemImage: "xmark")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)

        ForEach(prompt.choices.filter { $0.id != "approve" && $0.id != "deny" }) { choice in
            Button {
                send(.choice, choiceID: choice.id)
            } label: {
                Text(verbatim: choice.title).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func answeredSummary(_ item: InboxPrompt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let answeredAt = item.answeredAt {
                Label("Answered \(EarshotFormat.relative(answeredAt))", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                if let summary = item.answerSummary {
                    Text(verbatim: summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Closed on your Mac", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: Actions

    private var trimmedReply: String {
        reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func closeTitle(_ prompt: WirePrompt) -> String {
        switch prompt.kind {
        case .question, .approval, .nudge:
            return "Not now"
        case .answer, .digest, .info:
            return "Done"
        }
    }

    private func sendReply() {
        let text = trimmedReply
        guard !text.isEmpty else { return }
        send(.text, text: text)
        reply = ""
    }

    private func send(_ mode: AnswerMode, choiceID: String? = nil, text: String? = nil) {
        prompts.answer(promptID, mode: mode, choiceID: choiceID, text: text)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Say it

/// The voice window's bookkeeping, shared by the sheet's task and its onDisappear. A
/// reference, so both see the same values even after the sheet is gone: the task can
/// resume (the microphone permission prompt, for one) after onDisappear has run.
private final class VoiceWindowLifecycle {
    var token: VoiceWindowToken?
    var startedAt: Date?
    /// The sheet went away.
    var closed = false
    /// The window was ended or cancelled.
    var finished = false
}

/// A 20-second listening window. The recorder captures the answer; the Mac reads
/// the transcript after `answeredAt`.
private struct VoiceAnswerSheet: View {
    let promptID: String

    @EnvironmentObject private var prompts: PromptCenter
    @EnvironmentObject private var recorder: AudioCapture
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case starting
        case listening
        case failed(String)
        case sent
    }

    private static let window: Double = 20

    @State private var phase: Phase = .starting
    @State private var lifecycle = VoiceWindowLifecycle()

    var body: some View {
        VStack(spacing: 8) {
            switch phase {
            case .starting:
                ProgressView()
                Text("Starting the microphone…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .listening:
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    listening(now: context.date)
                }
            case .failed(let message):
                Image(systemName: "mic.slash.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text(verbatim: message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Close") { dismiss() }
            case .sent:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Got it — your Mac will listen to that.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 4)
        .task { await run() }
        .onDisappear { abandonIfNeeded() }
    }

    private func listening(now: Date) -> some View {
        let elapsed = lifecycle.startedAt.map { now.timeIntervalSince($0) } ?? 0
        let remaining = max(0, Int((VoiceAnswerSheet.window - elapsed).rounded(.up)))
        return VStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.red)
                .symbolEffect(.pulse)
            Text(verbatim: "\(remaining)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("Speak your answer")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                finish()
            } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(elapsed < 1)
        }
    }

    private func run() async {
        let lifecycle = self.lifecycle
        guard lifecycle.token == nil, !lifecycle.closed, !lifecycle.finished, phase == .starting else { return }
        guard let newToken = await recorder.beginVoiceWindow() else {
            guard !lifecycle.closed else { return }
            phase = .failed(recorder.notice ?? "The microphone couldn't start.")
            Haptics.failure()
            return
        }
        if Task.isCancelled || lifecycle.closed {
            // The sheet went away while the microphone was starting; onDisappear had no
            // window to close then, so close it here or the microphone would stay on.
            lifecycle.finished = true
            recorder.cancelVoiceWindow(newToken)
            return
        }
        lifecycle.token = newToken
        lifecycle.startedAt = Date()
        phase = .listening
        Haptics.start()
        try? await Task.sleep(nanoseconds: UInt64(VoiceAnswerSheet.window * 1_000_000_000))
        if Task.isCancelled || lifecycle.closed {
            abandonIfNeeded()
        } else {
            finish()
        }
    }

    private func finish() {
        let lifecycle = self.lifecycle
        guard !lifecycle.finished, let token = lifecycle.token, let startedAt = lifecycle.startedAt else { return }
        lifecycle.finished = true
        let seconds = min(VoiceAnswerSheet.window, max(1, Date().timeIntervalSince(startedAt)))
        prompts.answer(promptID, mode: .voiceWindow, answeredAt: startedAt, voiceWindowSeconds: seconds.rounded())
        recorder.endVoiceWindow(token)
        guard !lifecycle.closed else { return }
        phase = .sent
        Haptics.success()
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        }
    }

    /// The sheet went away (or its task was cancelled) before the window ended.
    private func abandonIfNeeded() {
        let lifecycle = self.lifecycle
        lifecycle.closed = true
        guard !lifecycle.finished, let token = lifecycle.token else { return }
        if let startedAt = lifecycle.startedAt, Date().timeIntervalSince(startedAt) >= 3 {
            // Long enough to have said something: treat it like "Done".
            finish()
        } else {
            lifecycle.finished = true
            recorder.cancelVoiceWindow(token)
        }
    }
}
