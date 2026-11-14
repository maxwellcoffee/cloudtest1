//  RequestView.swift
//  Earshot (watchOS)
//
//  Ask (a question for your memory), Do (a task for the Mac agent) or Note
//  (something to remember). Text comes from dictation, Scribble or the keyboard.
//  Answers arrive later in the Inbox.

import SwiftUI

struct RequestView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var queue: SegmentQueue

    @State private var kind: WatchRequestKind
    @State private var text = ""
    @State private var sentID: String? = nil
    @State private var sentKind: WatchRequestKind = .ask

    init(kind: WatchRequestKind = .ask) {
        _kind = State(initialValue: kind)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    modeButton(.ask)
                    modeButton(.command)
                    modeButton(.note)
                }

                Text(verbatim: hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Request", text: $text, prompt: Text(verbatim: placeholder))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)

                Button {
                    send()
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(RequestView.tint(kind))
                .disabled(trimmed.isEmpty)

                if let sentID {
                    acknowledgement(for: sentID)
                }

                if store.pairingStatus != .paired {
                    StatusText(text: "Not paired — requests wait on the watch until you pair.",
                               systemImage: "link", tint: .yellow)
                }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(RequestView.title(kind))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Pieces

    private func modeButton(_ mode: WatchRequestKind) -> some View {
        let selected = kind == mode
        return Button {
            kind = mode
            Haptics.click()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: RequestView.symbol(mode))
                    .font(.system(size: 16, weight: .semibold))
                Text(verbatim: RequestView.title(mode))
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(selected ? Color.white : RequestView.tint(mode))
            .background(selected ? RequestView.tint(mode) : RequestView.tint(mode).opacity(0.2),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(RequestView.title(mode))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func acknowledgement(for id: String) -> some View {
        if let ack = queue.requestAcks[id] {
            VStack(spacing: 4) {
                StatusText(text: ack.message.isEmpty ? (ack.accepted ? "Sent." : "Not accepted.") : ack.message,
                           systemImage: ack.accepted ? "checkmark.circle.fill" : "xmark.octagon.fill",
                           tint: ack.accepted ? .green : .red)
                if ack.accepted && sentKind != .note {
                    Text("The answer will appear in your Inbox.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else if queue.isPending(requestID: id) {
            StatusText(text: queue.isUploading ? "Sending…" : "Queued — sends when your Mac is reachable.",
                       systemImage: "clock", tint: .secondary)
        } else {
            StatusText(text: "Sent.", systemImage: "checkmark.circle", tint: .green)
        }
    }

    // MARK: Behaviour

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        guard let id = store.sendRequest(kind: kind, text: trimmed) else { return }
        sentID = id
        sentKind = kind
        text = ""
    }

    private var hint: String {
        switch kind {
        case .ask: return "Ask about anything you've heard or said."
        case .command: return "Tell your Mac what to do. Risky steps ask for approval."
        case .note: return "Save something to remember."
        }
    }

    private var placeholder: String {
        switch kind {
        case .ask: return "What did Sam say about the deadline?"
        case .command: return "Draft an email to Sam with today's decisions"
        case .note: return "Parking spot 4C"
        }
    }

    private static func title(_ kind: WatchRequestKind) -> String {
        switch kind {
        case .ask: return "Ask"
        case .command: return "Do"
        case .note: return "Note"
        }
    }

    private static func symbol(_ kind: WatchRequestKind) -> String {
        switch kind {
        case .ask: return "questionmark.bubble.fill"
        case .command: return "bolt.fill"
        case .note: return "note.text"
        }
    }

    private static func tint(_ kind: WatchRequestKind) -> Color {
        switch kind {
        case .ask: return .blue
        case .command: return .purple
        case .note: return .teal
        }
    }
}
