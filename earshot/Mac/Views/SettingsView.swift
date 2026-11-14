//  SettingsView.swift
//  Every AppSettings field, API keys, permissions and data management. Used
//  both in the main window's sidebar and in the Settings scene.

import SwiftUI
import AppKit
import AVFoundation
import Speech

struct EarshotSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SettingsTabs(store: model.settings)
    }
}

private struct SettingsTabs: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        TabView {
            ProfileSettingsTab(store: store)
                .tabItem { Label("You", systemImage: "person.crop.circle") }
            AISettingsTab(store: store)
                .tabItem { Label("AI", systemImage: "sparkles") }
            TranscriptionSettingsTab(store: store)
                .tabItem { Label("Transcription", systemImage: "waveform") }
            RecordingSettingsTab(store: store)
                .tabItem { Label("Recording", systemImage: "record.circle") }
            QuestionsSettingsTab(store: store)
                .tabItem { Label("Questions", systemImage: "bubble.left") }
            ActionsSettingsTab(store: store)
                .tabItem { Label("Actions", systemImage: "bolt") }
            PermissionsSettingsTab()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
            DataSettingsTab(store: store)
                .tabItem { Label("Data", systemImage: "externaldrive") }
            IntegrationsSettingsTab(store: store)
                .tabItem { Label("Integrations", systemImage: "puzzlepiece.extension") }
        }
        .padding(.top, 6)
    }
}

private enum SettingsText {
    static let efforts = ["low", "medium", "high", "xhigh", "max"]
    static let modelSuggestions = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
    static let localeSuggestions = ["en-US", "en-GB", "en-AU", "en-IN", "de-DE", "fr-FR", "es-ES", "es-MX",
                                    "it-IT", "pt-BR", "nl-NL", "sv-SE", "ja-JP", "zh-CN", "ko-KR"]

    static var isMacOS26: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
    }

    static func effortLabel(_ effort: String) -> String {
        switch effort {
        case "xhigh": return "Extra high"
        default: return effort.capitalized
        }
    }

    static func localeName(_ identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }
}

private struct SettingsFooter: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - You

private struct ProfileSettingsTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $store.settings.userName)
                TextField("About you", text: $store.settings.aboutMe, axis: .vertical)
                    .lineLimit(3...8)
                TextField("Life goals", text: $store.settings.lifeGoals, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("About you")
            } footer: {
                SettingsFooter("Shared with the AI with every request, so insights, questions and digests are about your life: your work, the people who matter, what you're working toward.")
            }
            Section {
                TextField("Name shown to the watch", text: $store.settings.macDisplayName,
                          prompt: Text(EarshotFormat.defaultMacName))
            } header: {
                Text("This Mac")
            } footer: {
                SettingsFooter("Leave empty to use the computer's name.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - AI

private struct AISettingsTab: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Model provider", selection: $store.settings.llmBackend) {
                    ForEach(LLMBackend.allCases) { backend in
                        Text(backend.label).tag(backend)
                    }
                }
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        EarshotStatusDot(model.aiConfigured ? .green : .orange)
                        Text(model.aiConfigured ? model.aiBackendDescription : "Not configured")
                            .foregroundStyle(.secondary)
                    }
                }
                if store.settings.llmBackend == .appleOnDevice && !SettingsText.isMacOS26 {
                    SettingsFooter("The on-device model needs macOS 26 with Apple Intelligence. Earshot uses Claude when a key is set.")
                }
            } header: {
                Text("Backend")
            }

            Section {
                SecureField("Anthropic API key", text: $store.anthropicAPIKey, prompt: Text("sk-ant-…"))
                if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                    Link("Get an API key from the Anthropic Console", destination: url)
                        .font(.callout)
                }
            } header: {
                Text("Claude")
            } footer: {
                SettingsFooter("Stored in your Keychain. Transcripts are sent to Anthropic only for analysis, digests, Ask and the agent.")
            }

            Section {
                ModelField(title: "Main model", text: $store.settings.claudeModel)
                SettingsFooter("Used for the agent, digests and Ask.")
                ModelField(title: "Background model", text: $store.settings.claudeBackgroundModel)
                SettingsFooter("Used for frequent transcript analysis. claude-haiku-5-5 is much cheaper for this background work; claude-opus-5-5 notices more.")
                Picker("Background effort", selection: $store.settings.backgroundEffort) {
                    ForEach(SettingsText.efforts, id: \.self) { effort in
                        Text(SettingsText.effortLabel(effort)).tag(effort)
                    }
                }
                Picker("Agent effort", selection: $store.settings.agentEffort) {
                    ForEach(SettingsText.efforts, id: \.self) { effort in
                        Text(SettingsText.effortLabel(effort)).tag(effort)
                    }
                }
            } header: {
                Text("Models")
            }

            Section {
                Stepper("Analyze every \(store.settings.analysisIntervalMinutes) minutes",
                        value: $store.settings.analysisIntervalMinutes, in: 5...180, step: 5)
                Stepper("Only after \(store.settings.analysisMinWords) new words",
                        value: $store.settings.analysisMinWords, in: 20...3000, step: 20)
            } header: {
                Text("Analysis")
            } footer: {
                SettingsFooter("New transcripts are also analyzed at most every 3 minutes once enough has been said.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: store.anthropicAPIKey) {
            model.refreshAIStatus()
        }
        .onChange(of: store.settings.llmBackend) {
            model.refreshAIStatus()
        }
    }
}

private struct ModelField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            TextField(title, text: $text)
            Menu {
                ForEach(SettingsText.modelSuggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        text = suggestion
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Suggested models")
        }
    }
}

// MARK: - Transcription

private struct TranscriptionSettingsTab: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Engine", selection: $store.settings.transcriptionEngine) {
                    ForEach(TranscriptionEngine.allCases) { engine in
                        Text(engine.label).tag(engine)
                    }
                }
                if store.settings.transcriptionEngine == .speechAnalyzer && !SettingsText.isMacOS26 {
                    SettingsFooter("SpeechAnalyzer needs macOS 26. On this Mac Earshot uses Apple Speech instead.")
                }
                HStack(spacing: 6) {
                    TextField("Language", text: $store.settings.localeIdentifier)
                    Menu {
                        ForEach(SettingsText.localeSuggestions, id: \.self) { identifier in
                            Button("\(SettingsText.localeName(identifier)) (\(identifier))") {
                                store.settings.localeIdentifier = identifier
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderless)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                SettingsFooter("Recognised as \(SettingsText.localeName(store.settings.localeIdentifier)).")
            } header: {
                Text("Speech to text")
            }

            if store.settings.transcriptionEngine == .whisperAPI {
                Section {
                    TextField("Base URL", text: $store.settings.whisperBaseURL)
                    TextField("Model", text: $store.settings.whisperModel)
                    SecureField("API key", text: $store.whisperAPIKey)
                } header: {
                    Text("Whisper-compatible API")
                } footer: {
                    SettingsFooter("Audio is uploaded to {base URL}/audio/transcriptions. The key is stored in your Keychain.")
                }
            }

            Section {
                SpeechPermissionRow()
            } header: {
                Text("Permission")
            }
        }
        .formStyle(.grouped)
    }
}

private struct SpeechPermissionRow: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            let status = SFSpeechRecognizer.authorizationStatus()
            EarshotPermissionRow("Speech recognition",
                                 detail: "Needed for Apple's on-device transcription.",
                                 symbol: "waveform",
                                 access: PermissionStatus.speech(status),
                                 actionTitle: status == .notDetermined ? "Grant Speech Recognition" : "Open Settings") {
                if status == .notDetermined {
                    Task { await model.requestSpeechAccess() }
                } else {
                    EarshotSystemSettings.openPrivacyPane("Privacy_SpeechRecognition")
                }
            }
        }
    }
}

// MARK: - Recording

private struct RecordingSettingsTab: View {
    @ObservedObject var store: SettingsStore

    private var keepAudioText: String {
        let days = store.settings.keepAudioDays
        if days == 0 { return "Delete audio right after transcription" }
        return days == 1 ? "Keep audio for 1 day" : "Keep audio for \(days) days"
    }

    var body: some View {
        Form {
            Section {
                Stepper("Segment length: \(store.settings.segmentSeconds) seconds",
                        value: $store.settings.segmentSeconds, in: 30...600, step: 30)
                LabeledContent("Silence threshold") {
                    HStack {
                        Slider(value: $store.settings.silenceThresholdDB, in: -70.0 ... -20.0, step: 1)
                            .frame(maxWidth: 220)
                        Text(String(format: "%.0f dB", Double(store.settings.silenceThresholdDB)))
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Toggle("Skip segments without speech", isOn: $store.settings.skipSilentSegments)
                LabeledContent("Stop recording below") {
                    HStack {
                        Slider(value: $store.settings.lowBatteryStopLevel, in: 0.0 ... 0.5, step: 0.05)
                            .frame(maxWidth: 220)
                        Text(String(format: "%.0f%%", Double(store.settings.lowBatteryStopLevel) * 100))
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            } header: {
                Text("Watch recording")
            } footer: {
                SettingsFooter("Sent to the watch on every sync. Lower thresholds keep quieter speech; segments with almost no speech are not transcribed.")
            }

            Section {
                Stepper(keepAudioText, value: $store.settings.keepAudioDays, in: 0...365)
            } header: {
                Text("Storage")
            } footer: {
                SettingsFooter("Transcripts are always kept until you forget or erase them.")
            }

            Section {
                TextField("Port", value: $store.settings.serverPort, format: .number.grouping(.never))
                SettingsFooter("The watch connects to http://<this Mac>:\(String(store.settings.serverPort)). Changes apply after restarting Earshot.")
            } header: {
                Text("Server")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Questions & digest

private struct QuestionsSettingsTab: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Ask me questions on my watch", isOn: $store.settings.questionsEnabled)
                Stepper("At most \(store.settings.maxQuestionsPerDay) per day",
                        value: $store.settings.maxQuestionsPerDay, in: 0...20)
                    .disabled(!store.settings.questionsEnabled)
                Stepper("At least \(store.settings.minMinutesBetweenQuestions) minutes apart",
                        value: $store.settings.minMinutesBetweenQuestions, in: 10...480, step: 5)
                    .disabled(!store.settings.questionsEnabled)
                Toggle("Wait while I'm in a conversation", isOn: $store.settings.avoidQuestionsDuringConversation)
                Toggle("Wait until calendar meetings end", isOn: $store.settings.avoidQuestionsDuringMeetings)
                if !model.questionStatus.isEmpty {
                    LabeledContent("Last decision") {
                        Text(model.questionStatus)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("Proactive questions")
            } footer: {
                SettingsFooter("Answers to your own requests, approvals and digests always come through.")
            }

            Section {
                HourPicker(title: "Quiet hours start", hour: $store.settings.quietHoursStart)
                HourPicker(title: "Quiet hours end", hour: $store.settings.quietHoursEnd)
            } header: {
                Text("Quiet hours")
            } footer: {
                SettingsFooter("No questions or nudges between these times.")
            }

            Section {
                HourPicker(title: "Write the daily digest after", hour: $store.settings.dailyDigestHour)
                Picker("Weekly review on", selection: $store.settings.weeklyReviewWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                    }
                }
            } header: {
                Text("Digest")
            }
        }
        .formStyle(.grouped)
    }
}

private struct HourPicker: View {
    let title: String
    @Binding var hour: Int

    var body: some View {
        Picker(title, selection: $hour) {
            ForEach(0..<24, id: \.self) { value in
                Text(EarshotFormat.hourLabel(value)).tag(value)
            }
        }
    }
}

// MARK: - Actions & agent

private struct ActionsSettingsTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Run low-risk actions automatically", isOn: $store.settings.autoApproveLowRisk)
                SettingsFooter("Low risk: saving notes.")
                Toggle("Run medium-risk actions automatically", isOn: $store.settings.autoApproveMediumRisk)
                SettingsFooter("Medium risk: reminders, calendar events, email drafts (never sent), opening links and apps.")
                SettingsFooter("High risk (Shortcuts, AppleScript and agent tasks) always waits for your approval.")
            } header: {
                Text("Approvals")
            }

            Section {
                Toggle("Allow the agent to see and control the screen", isOn: $store.settings.computerUseEnabled)
                Stepper("Up to \(store.settings.agentMaxSteps) steps per task",
                        value: $store.settings.agentMaxSteps, in: 5...200, step: 5)
                if store.settings.computerUseEnabled {
                    ComputerUsePermissionRows()
                }
            } header: {
                Text("Agent & computer use")
            } footer: {
                SettingsFooter("With computer use the agent takes screenshots and uses the mouse and keyboard. Risky steps ask you first, on the Mac or your watch.")
            }

            Section {
                LabeledContent("Notes folder") {
                    HStack(spacing: 8) {
                        Text((store.settings.notesFolderPath as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Choose…") {
                            chooseNotesFolder()
                        }
                        Button {
                            revealNotesFolder()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Show in Finder")
                    }
                }
                Toggle("Also create notes in Apple Notes", isOn: $store.settings.alsoCreateAppleNotes)
            } header: {
                Text("Notes")
            } footer: {
                SettingsFooter("Notes are saved as Markdown files in this folder.")
            }
        }
        .formStyle(.grouped)
    }

    private func chooseNotesFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Notes Folder"
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: store.settings.notesFolderPath, isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            store.settings.notesFolderPath = url.path
        }
    }

    private func revealNotesFolder() {
        let url = URL(fileURLWithPath: store.settings.notesFolderPath, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            Log.error("Settings: could not create the notes folder: \(error.localizedDescription)")
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

private struct ComputerUsePermissionRows: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            VStack(alignment: .leading, spacing: 4) {
                EarshotPermissionRow("Accessibility",
                                     detail: "Lets the agent click and type.",
                                     symbol: "accessibility",
                                     access: ComputerControl.hasAccessibility ? .granted : .notDetermined,
                                     actionTitle: "Allow…") {
                    ComputerControl.requestAccessibility()
                }
                EarshotPermissionRow("Screen Recording",
                                     detail: "Lets the agent see the screen.",
                                     symbol: "rectangle.dashed.badge.record",
                                     access: ComputerControl.hasScreenRecording ? .granted : .notDetermined,
                                     actionTitle: "Allow…") {
                    ComputerControl.requestScreenRecording()
                }
            }
        }
    }
}

// MARK: - Permissions

private enum PermissionStatus {
    static func speech(_ status: SFSpeechRecognizerAuthorizationStatus) -> EarshotPermissionRow.Access {
        switch status {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func microphone(_ status: AVAuthorizationStatus) -> EarshotPermissionRow.Access {
        switch status {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}

private struct PermissionsSettingsTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            Form {
                Section {
                    calendarRow
                    speechRow
                    microphoneRow
                } header: {
                    Text("Privacy")
                }
                Section {
                    EarshotPermissionRow("Accessibility",
                                         detail: "Computer use: lets the agent click and type.",
                                         symbol: "accessibility",
                                         access: ComputerControl.hasAccessibility ? .granted : .notDetermined,
                                         actionTitle: "Allow…") {
                        ComputerControl.requestAccessibility()
                    }
                    EarshotPermissionRow("Screen Recording",
                                         detail: "Computer use: lets the agent see the screen.",
                                         symbol: "rectangle.dashed.badge.record",
                                         access: ComputerControl.hasScreenRecording ? .granted : .notDetermined,
                                         actionTitle: "Allow…") {
                        ComputerControl.requestScreenRecording()
                    }
                    EarshotPermissionRow("Automation",
                                         detail: "macOS asks the first time Earshot controls Mail, Notes, Shortcuts or another app. You can change it any time.",
                                         symbol: "gearshape.2",
                                         access: .info,
                                         actionTitle: "Open Settings") {
                        EarshotSystemSettings.openPrivacyPane("Privacy_Automation")
                    }
                } header: {
                    Text("Mac agent")
                }
                Section {
                    EarshotPermissionRow("Local network",
                                         detail: "Your watch reaches this Mac over the local network. If macOS asks, allow it.",
                                         symbol: "network",
                                         access: model.serverRunning ? .granted : .info)
                } header: {
                    Text("Network")
                }
            }
            .formStyle(.grouped)
        }
        .id(model.permissionsRevision)
    }

    private var calendarRow: some View {
        let granted = model.calendar.hasEventAccess && model.calendar.hasReminderAccess
        return EarshotPermissionRow("Calendar & Reminders",
                                    detail: "Avoids interrupting meetings and adds events and reminders you approve.",
                                    symbol: "calendar",
                                    access: granted ? .granted : .notDetermined,
                                    actionTitle: "Request Access") {
            Task {
                let ok = await model.requestCalendarAccess()
                if !ok {
                    EarshotSystemSettings.openPrivacyPane("Privacy_Calendars")
                }
            }
        }
    }

    private var speechRow: some View {
        let status = SFSpeechRecognizer.authorizationStatus()
        return EarshotPermissionRow("Speech recognition",
                                    detail: "Transcribes recordings on this Mac.",
                                    symbol: "waveform",
                                    access: PermissionStatus.speech(status),
                                    actionTitle: status == .notDetermined ? "Request" : "Open Settings") {
            if status == .notDetermined {
                Task { await model.requestSpeechAccess() }
            } else {
                EarshotSystemSettings.openPrivacyPane("Privacy_SpeechRecognition")
            }
        }
    }

    private var microphoneRow: some View {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return EarshotPermissionRow("Microphone",
                                    detail: "Only for desk mode, when this Mac records instead of your watch.",
                                    symbol: "mic",
                                    access: PermissionStatus.microphone(status),
                                    actionTitle: status == .notDetermined ? "Request" : "Open Settings") {
            if status == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    Log.info("Settings: microphone access \(granted ? "granted" : "denied").")
                }
            } else {
                EarshotSystemSettings.openPrivacyPane("Privacy_Microphone")
            }
        }
    }
}

// MARK: - Data

private struct DataSettingsTab: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var store: SettingsStore
    @State var confirmErase = false
    @State var confirmForget = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Data folder") {
                    HStack(spacing: 8) {
                        Text((AppPaths.supportDirectory.path as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([AppPaths.databaseURL])
                        }
                    }
                }
                LabeledContent("Raw audio") {
                    Text(store.settings.keepAudioDays == 0
                         ? "Deleted after transcription"
                         : "Kept for \(store.settings.keepAudioDays) days")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Storage")
            } footer: {
                SettingsFooter("Everything Earshot records and learns stays in this folder on your Mac.")
            }

            Section {
                Toggle("Redact personal details before text goes to the cloud", isOn: $store.settings.redactBeforeCloud)
            } header: {
                Text("Privacy")
            } footer: {
                SettingsFooter("Before transcript text is sent to Claude for analysis, questions, digests and Ask, Earshot replaces e-mail addresses, phone numbers, payment-card numbers, IBANs and account numbers, US Social Security numbers and one-time codes or PINs with placeholders such as [email], [phone] or [card]. Redaction runs on your Mac and your stored transcripts keep the original text. Names and other details are still sent; the on-device model needs no redaction, and agent tasks are sent as written because the agent needs real addresses to act.")
            }

            Section {
                HStack(spacing: 10) {
                    Button("Export Everything…") {
                        model.exportAll()
                    }
                    .disabled(model.isExporting || model.isErasing)
                    if model.isExporting {
                        ProgressView()
                            .controlSize(.small)
                        Text("Exporting…")
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = model.exportError, !model.isExporting {
                    EarshotNotice("Export failed: \(error)", tint: .red)
                }
                if let exported = model.lastExportURL, !model.isExporting {
                    LabeledContent("Last export") {
                        HStack(spacing: 8) {
                            Text(exported.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([exported])
                            }
                        }
                    }
                }
            } header: {
                Text("Export")
            } footer: {
                SettingsFooter("Saves a copy of everything in open formats you can read without Earshot: one Markdown transcript per day, digests as Markdown, insights, goals, questions and actions as JSON, and a README that explains every file. Raw audio is not included.")
            }

            Section {
                Button("Forget the Last 15 Minutes…") {
                    confirmForget = true
                }
                Button("Clear Ask History") {
                    model.clearChat()
                }
                .disabled(model.chat.isEmpty)
            } header: {
                Text("Forget")
            }

            Section {
                HStack(spacing: 10) {
                    Button("Erase All Data…", role: .destructive) {
                        confirmErase = true
                    }
                    .disabled(model.isErasing || model.isExporting)
                    if model.isErasing {
                        ProgressView()
                            .controlSize(.small)
                        Text("Erasing…")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Erase")
            } footer: {
                SettingsFooter("Deletes every transcript, recording, insight, question, action, goal, digest, chat and paired device. Settings and API keys are kept.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Erase all Earshot data?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                model.eraseAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone. Your watch will need to be paired again.")
        }
        .confirmationDialog("Forget the last 15 minutes?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Forget", role: .destructive) {
                let end = Date()
                model.forget(from: end.addingTimeInterval(-15 * 60), to: end)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The transcript and recorded audio of the last 15 minutes are deleted permanently.")
        }
    }
}

// MARK: - Integrations

private struct IntegrationsSettingsTab: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var store: SettingsStore
    @State private var showToken = false
    @State private var confirmRotate = false
    /// Which value was just copied ("endpoint", "token", "config"), for the button's feedback.
    @State private var copiedItem: String? = nil

    private var token: String { model.mcp.token }

    private var endpoint: String {
        "http://127.0.0.1:\(String(model.server.port))\(EarshotAPI.Path.mcp)"
    }

    private var maskedToken: String {
        String(repeating: "•", count: 16) + String(token.suffix(4))
    }

    private var statusText: String {
        if !store.settings.mcpEnabled { return "Off" }
        if model.serverRunning { return "Serving on port \(String(model.server.port))" }
        if let error = model.serverError?.nilIfEmpty { return "Server not running: \(error)" }
        return "Server not running"
    }

    private var statusColor: Color {
        if !store.settings.mcpEnabled { return .gray }
        return model.serverRunning ? .green : .orange
    }

    var body: some View {
        Form {
            Section {
                Toggle("Let AI apps read my memory over MCP", isOn: $store.settings.mcpEnabled)
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        EarshotStatusDot(statusColor)
                        Text(statusText)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("Model Context Protocol")
            } footer: {
                SettingsFooter("Claude and other MCP clients can search your transcripts, read a day's transcript, list open tasks, promises and questions, read goals and digests, and ask your memory a question. Every tool is read-only: nothing can be changed or deleted through MCP.")
            }

            Section {
                LabeledContent("Endpoint") {
                    HStack(spacing: 8) {
                        Text(endpoint)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Button(copyTitle("Copy", item: "endpoint")) {
                            copyToPasteboard(endpoint, item: "endpoint")
                        }
                    }
                }
                LabeledContent("Token") {
                    HStack(spacing: 8) {
                        Text(showToken ? token : maskedToken)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(showToken ? "Hide the token" : "Show the token")
                        Button(copyTitle("Copy", item: "token")) {
                            copyToPasteboard(token, item: "token")
                        }
                        Button("Rotate…") {
                            confirmRotate = true
                        }
                    }
                }
                if store.settings.serverPort != Int(model.server.port) {
                    SettingsFooter("The port changes to \(String(store.settings.serverPort)) after you restart Earshot.")
                }
            } header: {
                Text("Connection")
            } footer: {
                SettingsFooter("Clients send the token as “Authorization: Bearer <token>”. Anyone with it can read your memory, so treat it like a password. Rotate it to cut off every client at once.")
            }

            Section {
                Text(IntegrationsSettingsTab.clientConfig(url: endpoint, token: showToken ? token : maskedToken))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Spacer()
                    Button(copyTitle("Copy Configuration", item: "config")) {
                        copyToPasteboard(IntegrationsSettingsTab.clientConfig(url: endpoint, token: token), item: "config")
                    }
                }
            } header: {
                Text("Client configuration")
            } footer: {
                SettingsFooter("Paste this into your MCP client's configuration, for example a project's .mcp.json for Claude Code. The copied text contains the real token.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Create a new MCP token?", isPresented: $confirmRotate, titleVisibility: .visible) {
            Button("Rotate Token", role: .destructive) {
                model.rotateMCPToken()
                copiedItem = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apps using the current token lose access until you give them the new one.")
        }
    }

    /// "Copied" for two seconds after `item` was copied, otherwise `title`.
    private func copyTitle(_ title: String, item: String) -> String {
        copiedItem == item ? "Copied" : title
    }

    private func copyToPasteboard(_ text: String, item: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedItem = item
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if copiedItem == item { copiedItem = nil }
        }
    }

    /// A ready-to-paste MCP client entry (Streamable HTTP with a bearer token).
    private static func clientConfig(url: String, token: String) -> String {
        """
        {
          "mcpServers": {
            "earshot": {
              "type": "http",
              "url": "\(url)",
              "headers": {
                "Authorization": "Bearer \(token)"
              }
            }
          }
        }
        """
    }
}
