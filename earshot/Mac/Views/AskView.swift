//  AskView.swift
//  Chat over everything Earshot transcribed (MemoryChat), with quoted
//  citations that jump to the moment in Today.

import SwiftUI
import AppKit

struct EarshotAskView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private static let suggestions = [
        "What did I promise today?",
        "What decisions did we make this week?",
        "What should I follow up on?",
        "Who did I talk to yesterday?",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ChatTranscript()
            Divider()
            composer
        }
        .navigationTitle("Ask")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.clearChat()
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .disabled(model.chat.isEmpty || model.pendingQuestion != nil)
                .help("Delete the chat history (your transcript is kept)")
            }
        }
        .onAppear {
            inputFocused = true
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            send(suggestion)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.pendingQuestion != nil)
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about anything you heard or said…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    .onSubmit {
                        send(draft)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                Button {
                    send(draft)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                }
                .buttonStyle(.borderless)
                .disabled(draft.trimmed.isEmpty || model.pendingQuestion != nil)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Ask (⌘↩)")
            }
            if !model.aiConfigured {
                Text("Ask needs AI: add an Anthropic API key in Settings → AI.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
    }

    private func send(_ text: String) {
        guard let question = text.nilIfEmpty, model.pendingQuestion == nil else { return }
        model.ask(question)
        draft = ""
    }
}

// MARK: - Transcript

private struct ChatTranscript: View {
    @EnvironmentObject var model: AppModel

    private static let bottomID = "ask-bottom"

    /// MemoryChat stores the question together with the answer; until then show it optimistically.
    private var pendingQuestionNeedsBubble: Bool {
        guard let question = model.pendingQuestion else { return false }
        guard let last = model.chat.last else { return true }
        return !(last.role == .user && last.text == question)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if model.chat.isEmpty && model.pendingQuestion == nil {
                        AskIntro()
                            .padding(.top, 40)
                    }
                    ForEach(model.chat) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    if let question = model.pendingQuestion {
                        if pendingQuestionNeedsBubble {
                            UserBubble(text: question, date: Date())
                        }
                        ThinkingBubble()
                    }
                    if let error = model.askError {
                        EarshotNotice(error, symbol: "exclamationmark.triangle.fill", tint: .red)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomID)
                }
                .padding(20)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: model.chat.count) {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(Self.bottomID, anchor: .bottom)
                }
            }
            .onChange(of: model.pendingQuestion) {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(Self.bottomID, anchor: .bottom)
                }
            }
        }
    }
}

private struct AskIntro: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Ask your memory")
                .font(.title2.weight(.semibold))
            Text("Earshot searches everything it transcribed and answers with quotes and the time they were said. Click a quote to jump to that moment.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            UserBubble(text: message.text, date: message.createdAt)
        case .assistant:
            AssistantBubble(message: message)
        }
    }
}

private struct UserBubble: View {
    let text: String
    let date: Date

    var body: some View {
        HStack {
            Spacer(minLength: 80)
            VStack(alignment: .trailing, spacing: 4) {
                Text(text)
                    .textSelection(.enabled)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(date.timeText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct AssistantBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 8) {
                EarshotMarkdownView(message.text)
                    .padding(12)
                    .background(EarshotPalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(EarshotPalette.cardBorder, lineWidth: 1)
                    )
                if !message.citations.isEmpty {
                    CitationList(citations: message.citations)
                }
                HStack(spacing: 10) {
                    Text(message.createdAt.timeText)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.text, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 60)
        }
    }
}

private struct CitationList: View {
    @EnvironmentObject var model: AppModel
    let citations: [Citation]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(citations.prefix(8).enumerated()), id: \.offset) { _, citation in
                Button {
                    model.show(date: citation.at, utteranceID: citation.utteranceID)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "quote.opening")
                            .foregroundStyle(.tint)
                        Text("“\(citation.quote.clipped(140))”")
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(citation.at.shortText)
                            .foregroundStyle(.tertiary)
                            .fixedSize()
                    }
                    .font(.caption)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Show this moment in the transcript")
            }
        }
    }
}

private struct ThinkingBubble: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Searching your memory…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 34)
    }
}
