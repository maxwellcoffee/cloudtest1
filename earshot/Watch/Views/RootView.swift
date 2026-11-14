//  RootView.swift
//  Earshot (watchOS)
//
//  Vertical pages: Record, Inbox, Today, Settings.

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var prompts: PromptCenter
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                RecordView()
            }
            .tag(WatchTab.record)

            NavigationStack(path: $store.inboxPath) {
                InboxView()
                    .navigationDestination(for: String.self) { promptID in
                        PromptDetailView(promptID: promptID)
                    }
            }
            .tag(WatchTab.inbox)

            NavigationStack {
                TodayView()
            }
            .tag(WatchTab.today)

            NavigationStack {
                SettingsView()
            }
            .tag(WatchTab.settings)
        }
        .tabViewStyle(.verticalPage)
        .overlay(alignment: .bottom) {
            if let arrival = prompts.arrival {
                ArrivalBanner(item: arrival) {
                    store.openPrompt(arrival.id)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: prompts.arrival?.id)
        .onChange(of: scenePhase, initial: true) { _, phase in
            store.scenePhaseChanged(phase)
        }
    }
}

/// Shown for a few seconds when a prompt arrives while the app is on screen.
private struct ArrivalBanner: View {
    let item: InboxPrompt
    let open: @MainActor () -> Void

    var body: some View {
        Button {
            open()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: PromptStyle.symbol(item.prompt.kind))
                    .foregroundStyle(PromptStyle.tint(item.prompt.kind))
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: PromptStyle.label(item.prompt.kind))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(verbatim: item.prompt.title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the prompt")
    }
}
