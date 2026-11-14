//  OnboardingView.swift
//  First-launch sheet: what Earshot does, privacy and consent, the API key,
//  permissions, and pairing the watch.

import SwiftUI
import AppKit
import Speech

struct EarshotOnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var page = 0
    @State private var consentGiven = false
    private let onFinish: () -> Void

    private static let pageCount = 5

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    private var isLastPage: Bool { page == EarshotOnboardingView.pageCount - 1 }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0:
                    OnboardingWelcomePage()
                case 1:
                    OnboardingConsentPage(consentGiven: $consentGiven)
                case 2:
                    OnboardingAIPage(store: model.settings)
                case 3:
                    OnboardingPermissionsPage()
                default:
                    OnboardingPairPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(32)

            Divider()

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(0..<EarshotOnboardingView.pageCount, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Color.accentColor : Color.primary.opacity(0.15))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if page > 0 {
                    Button("Back") {
                        page -= 1
                    }
                }
                if page >= 2 && !isLastPage {
                    Button("Skip") {
                        page += 1
                    }
                }
                Button(isLastPage ? "Start Using Earshot" : "Continue") {
                    if isLastPage {
                        onFinish()
                    } else {
                        page += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(page == 1 && !consentGiven)
            }
            .padding(16)
        }
        .frame(width: 640, height: 580)
    }
}

// MARK: - Pages

private struct OnboardingPageHeader: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 38))
                .foregroundStyle(.tint)
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }
}

private struct OnboardingPoint: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingPageHeader(symbol: "waveform",
                                 title: "Welcome to Earshot",
                                 subtitle: "Your Apple Watch listens to your day. This Mac transcribes it, remembers it, and helps you follow through.")
            OnboardingPoint(symbol: "text.bubble", title: "A searchable memory",
                            text: "Everything you say is transcribed on this Mac. Ask “what did Sam say about the deadline?” any time.")
            OnboardingPoint(symbol: "checklist", title: "Commitments and goals, tracked",
                            text: "Earshot notices promises, tasks and decisions, and writes a calm digest every evening.")
            OnboardingPoint(symbol: "applewatch", title: "Well-timed questions",
                            text: "Now and then it asks a short question on your watch, never during meetings or quiet hours.")
            OnboardingPoint(symbol: "sparkles", title: "Help on your Mac",
                            text: "With your approval it creates reminders, events, notes and email drafts, runs Shortcuts, or uses the computer for you.")
        }
    }
}

private struct OnboardingConsentPage: View {
    @Binding var consentGiven: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingPageHeader(symbol: "hand.raised",
                                     title: "Privacy & consent",
                                     subtitle: "Recording conversations comes with responsibility.")
                OnboardingPoint(symbol: "lock.shield", title: "Your data stays on your Mac",
                                text: "Audio and transcripts are stored only on this Mac. Raw audio is deleted after a few days. Text is sent to Anthropic's API only for analysis, digests, Ask and the agent (or stays fully on-device with Apple's model).")
                OnboardingPoint(symbol: "person.2", title: "Tell people Earshot is on",
                                text: "Many places require everyone's consent before a conversation is recorded. Let people know, and don't record where it isn't allowed.")
                OnboardingPoint(symbol: "pause.circle", title: "Pause when asked",
                                text: "Pause on your watch whenever someone asks, or for private moments. You can also forget any time range later.")
                Toggle(isOn: $consentGiven) {
                    Text("I'll tell people when I'm recording and pause when asked.")
                        .font(.callout.weight(.medium))
                }
                .toggleStyle(.checkbox)
                .padding(.top, 4)
            }
        }
    }
}

private struct OnboardingAIPage: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var store: SettingsStore

    private var onDeviceAvailable: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingPageHeader(symbol: "sparkles",
                                 title: "Connect Claude",
                                 subtitle: "Insights, questions, digests and the agent use Claude. Paste an Anthropic API key.")
            SecureField("Anthropic API key", text: $store.anthropicAPIKey, prompt: Text("sk-ant-…"))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)
            HStack(spacing: 6) {
                EarshotStatusDot(model.aiConfigured ? .green : .orange)
                Text(model.aiConfigured ? "Ready: \(model.aiBackendDescription)" : "No key yet. You can add it later in Settings → AI.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                Link("Get an API key from the Anthropic Console", destination: url)
            }
            Text("The key is stored in your Keychain. Background analysis uses \(store.settings.claudeBackgroundModel); switch it to claude-haiku-5-5 in Settings to save cost.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if onDeviceAvailable {
                Toggle("Use Apple's on-device model instead (private, offline)", isOn: Binding(
                    get: { store.settings.llmBackend == .appleOnDevice },
                    set: { store.settings.llmBackend = $0 ? .appleOnDevice : .claude }
                ))
                .toggleStyle(.checkbox)
            }
        }
        .onChange(of: store.anthropicAPIKey) {
            model.refreshAIStatus()
        }
        .onChange(of: store.settings.llmBackend) {
            model.refreshAIStatus()
        }
    }
}

private struct OnboardingPermissionsPage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingPageHeader(symbol: "checkmark.shield",
                                 title: "Permissions",
                                 subtitle: "Earshot asks only for what it needs. You can change these any time in System Settings.")
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    let calendarGranted = model.calendar.hasEventAccess && model.calendar.hasReminderAccess
                    EarshotPermissionRow("Calendar & Reminders",
                                         detail: "So questions never interrupt a meeting, and approved tasks become reminders.",
                                         symbol: "calendar",
                                         access: calendarGranted ? .granted : .notDetermined,
                                         actionTitle: "Allow") {
                        Task { await model.requestCalendarAccess() }
                    }
                    let speech = SFSpeechRecognizer.authorizationStatus()
                    EarshotPermissionRow("Speech recognition",
                                         detail: "Transcribes your recordings on this Mac.",
                                         symbol: "waveform",
                                         access: OnboardingPermissions.access(speech),
                                         actionTitle: speech == .notDetermined ? "Allow" : "Open Settings") {
                        if speech == .notDetermined {
                            Task { await model.requestSpeechAccess() }
                        } else {
                            EarshotSystemSettings.openPrivacyPane("Privacy_SpeechRecognition")
                        }
                    }
                    EarshotPermissionRow("Accessibility & Screen Recording",
                                         detail: "Optional: only if you let the agent use the computer. Turn it on later in Agent.",
                                         symbol: "cursorarrow.click",
                                         access: .info)
                }
            }
        }
        .id(model.permissionsRevision)
    }
}

private enum OnboardingPermissions {
    static func access(_ status: SFSpeechRecognizerAuthorizationStatus) -> EarshotPermissionRow.Access {
        switch status {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}

private struct OnboardingPairPage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingPageHeader(symbol: "applewatch",
                                 title: "Pair your Apple Watch",
                                 subtitle: "Open Earshot on your watch, go to Settings, and enter this Mac's address and the code.")
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pairing code")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    EarshotPairingCodeView()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server address")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    EarshotServerAddressList()
                }
            }
            if model.hasPairedWatch {
                Label("Your watch is paired.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Text("No watch with you? Turn on this Mac's microphone in Devices to use desk mode, or drop audio files on Today.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
