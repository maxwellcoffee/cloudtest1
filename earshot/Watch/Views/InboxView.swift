//  InboxView.swift
//  Earshot (watchOS)
//
//  Questions, approvals, answers and nudges from the Mac.

import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var prompts: PromptCenter

    var body: some View {
        let open = prompts.openPrompts
        let history = prompts.historyPrompts
        Group {
            if open.isEmpty && history.isEmpty {
                ContentUnavailableView("All caught up", systemImage: "tray",
                                       description: Text(emptyDescription))
            } else {
                List {
                    if !open.isEmpty {
                        Section {
                            ForEach(open) { item in
                                NavigationLink(value: item.id) {
                                    PromptRow(item: item)
                                }
                            }
                        } header: {
                            Text("Waiting")
                        }
                    }
                    if !history.isEmpty {
                        Section {
                            ForEach(history) { item in
                                NavigationLink(value: item.id) {
                                    PromptRow(item: item)
                                }
                            }
                        } header: {
                            Text("Earlier today")
                        }
                    }
                }
            }
        }
        .navigationTitle(InboxView.title(openCount: open.count))
        .containerBackground(Color.blue.gradient, for: .tabView)
        .onAppear { markVisibleAsShown() }
        .onChange(of: open.map(\.id)) { _, _ in markVisibleAsShown() }
        .onChange(of: store.selectedTab) { _, _ in markVisibleAsShown() }
    }

    private static func title(openCount: Int) -> String {
        openCount == 0 ? "Inbox" : "Inbox (\(openCount))"
    }

    private var emptyDescription: String {
        store.pairingStatus == .paired
            ? "Questions and answers from your Mac appear here."
            : "Pair with your Mac to get questions and answers here."
    }

    private func markVisibleAsShown() {
        guard store.selectedTab == .inbox else { return }
        prompts.markShown(prompts.openPrompts.map(\.id))
    }
}

private struct PromptRow: View {
    let item: InboxPrompt

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: PromptStyle.symbol(item.prompt.kind))
                .foregroundStyle(item.isOpen ? PromptStyle.tint(item.prompt.kind) : Color.secondary)
                .font(.body)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.prompt.title.isEmpty ? PromptStyle.label(item.prompt.kind) : item.prompt.title)
                    .font(.footnote.weight(item.isOpen ? .semibold : .regular))
                    .lineLimit(3)
                    .foregroundStyle(item.isOpen ? Color.primary : Color.secondary)
                Text(verbatim: subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if item.isOpen && item.prompt.priority >= 4 {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        if let summary = item.answerSummary, item.answeredAt != nil {
            return "↳ \(summary)"
        }
        if item.closedAt != nil {
            return "Closed on your Mac"
        }
        return "\(PromptStyle.label(item.prompt.kind)) · \(EarshotFormat.relative(item.prompt.createdAt))"
    }
}
