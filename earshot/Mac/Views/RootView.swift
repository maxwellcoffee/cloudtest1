//  RootView.swift
//  Main window: sidebar navigation, detail area, global toolbar status, and
//  the onboarding sheet on first launch.

import SwiftUI
import AppKit

struct EarshotRootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(AppModel.onboardingDefaultsKey) private var onboardingComplete = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView {
            RootSidebar(approvals: model.approvals)
                .navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 280)
        } detail: {
            RootDetail(item: model.sidebarSelection ?? .today)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                ServerStatusButton()
                WatchStatusButton()
                AnalyzeButton()
            }
        }
        .overlay(alignment: .bottom) {
            if let banner = model.banner {
                BannerView(banner: banner)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.banner)
        .sheet(isPresented: $showOnboarding) {
            EarshotOnboardingView {
                model.completeOnboarding()
                onboardingComplete = true
                showOnboarding = false
            }
            .environmentObject(model)
        }
        .onAppear {
            if !onboardingComplete {
                showOnboarding = true
            }
        }
    }
}

// MARK: - Sidebar

private struct RootSidebar: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var approvals: ApprovalCenter

    private var inboxCount: Int {
        approvals.pending.count + model.proposedActions.count + model.unansweredPromptCount
    }

    var body: some View {
        List(selection: $model.sidebarSelection) {
            Section("Earshot") {
                ForEach(AppModel.SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .badge(item == .inbox ? inboxCount : 0)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SidebarFooter()
        }
    }
}

private struct SidebarFooter: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
                Text(model.pipelineStatus)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Image(systemName: model.isAnalyzing ? "sparkles" : "checkmark.seal")
                    .foregroundStyle(.secondary)
                Text(model.analysisStatus)
                    .lineLimit(2)
            }
            if model.micRecorder.isRecording {
                HStack(spacing: 6) {
                    EarshotStatusDot(.red, size: 7)
                    Text("Mac microphone on")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

// MARK: - Detail

private struct RootDetail: View {
    @EnvironmentObject var model: AppModel
    let item: AppModel.SidebarItem

    var body: some View {
        VStack(spacing: 0) {
            if let warning = model.databaseWarning {
                EarshotNotice(warning, symbol: "externaldrive.badge.exclamationmark", tint: .red)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        switch item {
        case .today: EarshotTodayView()
        case .ask: EarshotAskView()
        case .inbox: EarshotInboxView()
        case .goals: EarshotGoalsView()
        case .digests: EarshotDigestsView()
        case .agent: EarshotAgentView()
        case .devices: EarshotDevicesView()
        case .settings: EarshotSettingsView()
        }
    }
}

// MARK: - Toolbar

private struct ServerStatusButton: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button {
            model.sidebarSelection = .devices
        } label: {
            HStack(spacing: 6) {
                EarshotStatusDot(model.serverRunning ? .green : .red)
                Text(model.serverRunning ? "Server" : "Server off")
                    .font(.callout)
            }
        }
        .help(helpText)
    }

    private var helpText: String {
        if model.serverRunning {
            return "Listening for your watch on port \(String(model.server.port))"
        }
        let reason = model.serverError ?? "unknown error"
        return "The server is not running: \(reason). Open Devices to restart it."
    }
}

private struct WatchStatusButton: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button {
            model.sidebarSelection = .devices
        } label: {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack(spacing: 6) {
                    Image(systemName: "applewatch")
                    Text(Self.text(lastSeen: model.lastWatchContact, paired: model.hasPairedWatch, now: context.date))
                        .font(.callout)
                }
                .foregroundStyle(Self.isRecent(model.lastWatchContact, now: context.date) ? Color.primary : Color.secondary)
            }
        }
        .help("When your watch last synced with this Mac")
    }

    private static func isRecent(_ date: Date?, now: Date) -> Bool {
        guard let date else { return false }
        return now.timeIntervalSince(date) < 180
    }

    private static func text(lastSeen: Date?, paired: Bool, now: Date) -> String {
        guard paired else { return "No watch" }
        guard let lastSeen else { return "Not seen yet" }
        if now.timeIntervalSince(lastSeen) < 60 { return "Just now" }
        return lastSeen.relativeText
    }
}

private struct AnalyzeButton: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button {
            model.analyzeNow()
        } label: {
            if model.isAnalyzing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing…")
                }
            } else {
                Label("Analyze Now", systemImage: "sparkles")
            }
        }
        .disabled(model.isAnalyzing)
        .help(model.analysisStatus)
    }
}

// MARK: - Banner

private struct BannerView: View {
    @EnvironmentObject var model: AppModel
    let banner: AppModel.Banner

    private var symbol: String {
        switch banner.style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(EarshotPalette.color(for: banner.style))
            Text(banner.text)
                .font(.callout)
                .lineLimit(3)
            Button {
                model.banner = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .frame(maxWidth: 560)
    }
}
