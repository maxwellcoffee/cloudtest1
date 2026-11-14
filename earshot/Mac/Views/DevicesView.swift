//  DevicesView.swift
//  Pairing the watch (code + server addresses), the local server, paired
//  devices with their last status, and the Mac microphone ("desk mode").

import SwiftUI
import AppKit

struct EarshotDevicesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var unpairCandidate: PairedDevice? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PairingCard()
                ServerCard(store: model.settings)
                PairedDevicesCard { device in
                    unpairCandidate = device
                }
                MacMicCard(mic: model.micRecorder, store: model.settings)
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Devices")
        .confirmationDialog("Unpair \(unpairCandidate?.name ?? "this device")?",
                            isPresented: unpairBinding,
                            titleVisibility: .visible,
                            presenting: unpairCandidate) { device in
            Button("Unpair", role: .destructive) {
                model.unpair(device)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It stops uploading until you pair it again with a new code. Recordings already on this Mac are kept.")
        }
    }

    private var unpairBinding: Binding<Bool> {
        Binding(get: { unpairCandidate != nil }, set: { presented in
            if !presented { unpairCandidate = nil }
        })
    }
}

// MARK: - Pairing

private struct PairingCard: View {
    var body: some View {
        EarshotCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                EarshotSectionHeader("Pair your Apple Watch", symbol: "applewatch",
                                     subtitle: "Your watch and this Mac need to be on the same network (or use a tunnel URL).")
                HStack(alignment: .top, spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pairing code")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        EarshotPairingCodeView()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        PairingStep(number: 1, text: "Open Earshot on your watch and go to Settings.")
                        PairingStep(number: 2, text: "Enter one of the server addresses below.")
                        PairingStep(number: 3, text: "Enter the pairing code. It changes every 10 minutes.")
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter this on your watch")
                        .font(.subheadline.weight(.semibold))
                    EarshotServerAddressList()
                }
            }
        }
    }
}

private struct PairingStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Server

private struct ServerCard: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var store: SettingsStore

    private var statusDetail: String {
        if model.serverRunning {
            let name = store.settings.macDisplayName.nilIfEmpty ?? EarshotFormat.defaultMacName
            return "Listening on port \(String(model.server.port)) as “\(name)”"
        }
        return model.serverError ?? "The watch can't upload until the server is running."
    }

    var body: some View {
        EarshotCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    EarshotStatusDot(model.serverRunning ? .green : .red, size: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.serverRunning ? "Server running" : "Server stopped")
                            .font(.headline)
                        Text(statusDetail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button {
                        model.restartServer()
                    } label: {
                        Label(model.serverRunning ? "Restart" : "Start", systemImage: "arrow.clockwise")
                    }
                }
                if store.settings.serverPort != Int(model.server.port) {
                    EarshotNotice("The port was changed to \(String(store.settings.serverPort)). Quit and reopen Earshot to use it.",
                                  symbol: "info.circle.fill", tint: .blue)
                }
                Text("Transcription: \(model.pipelineStatus)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Paired devices

private struct PairedDevicesCard: View {
    @EnvironmentObject var model: AppModel
    let onUnpair: (PairedDevice) -> Void

    var body: some View {
        EarshotCard {
            VStack(alignment: .leading, spacing: 12) {
                EarshotSectionHeader("Paired devices", symbol: "link", count: model.devices.count)
                if model.devices.isEmpty {
                    Text("No devices yet. Pair your watch with the code above.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(model.devices) { device in
                                DeviceRow(device: device, now: context.date) {
                                    onUnpair(device)
                                }
                                if device.id != model.devices.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DeviceRow: View {
    let device: PairedDevice
    let now: Date
    let onUnpair: () -> Void

    private var isConnected: Bool {
        guard let lastSeen = device.lastSeen else { return false }
        return now.timeIntervalSince(lastSeen) < 180
    }

    private var lastSeenText: String {
        guard let lastSeen = device.lastSeen else { return "Never synced" }
        if now.timeIntervalSince(lastSeen) < 60 { return "Synced just now" }
        return "Last synced \(lastSeen.relativeText)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: device.kind == "watch" ? "applewatch" : "desktopcomputer")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(device.name)
                        .font(.headline)
                    EarshotChip(isConnected ? "Connected" : "Offline", tint: isConnected ? .green : .secondary)
                }
                Text("\(lastSeenText) · paired \(device.pairedAt.shortText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let status = device.lastStatus {
                    DeviceStatusChips(status: status, now: now)
                }
            }
            Spacer(minLength: 8)
            Button("Unpair", role: .destructive, action: onUnpair)
                .controlSize(.small)
        }
        .padding(.vertical, 10)
    }
}

private struct DeviceStatusChips: View {
    let status: WatchStatusReport
    let now: Date

    private var recordingChip: (text: String, symbol: String, tint: Color) {
        if let pausedUntil = status.pausedUntil, pausedUntil > now {
            return ("Paused until \(pausedUntil.timeText)", "pause.circle", .orange)
        }
        if status.isRecording {
            return ("Recording", "record.circle", .red)
        }
        return ("Not recording", "stop.circle", .secondary)
    }

    var body: some View {
        let recording = recordingChip
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                EarshotChip(recording.text, symbol: recording.symbol, tint: recording.tint)
                EarshotChip(EarshotFormat.battery(status.batteryLevel),
                            symbol: EarshotFormat.batterySymbol(status.batteryLevel),
                            tint: status.batteryLevel >= 0 && status.batteryLevel < 0.2 ? .red : .secondary)
                EarshotChip(status.queuedSegments == 1 ? "1 segment queued" : "\(status.queuedSegments) segments queued",
                            symbol: "tray.and.arrow.up",
                            tint: status.queuedSegments > 20 ? .orange : .secondary)
            }
            HStack(spacing: 10) {
                Text("Today: \(EarshotFormat.duration(status.recordedSecondsToday)) recorded")
                if status.queuedBytes > 0 {
                    Text("· \(EarshotFormat.bytes(status.queuedBytes)) waiting")
                }
                if let last = status.lastSegmentAt {
                    Text("· last segment \(last.timeText)")
                }
                if !status.appVersion.isEmpty {
                    Text("· v\(status.appVersion)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Mac microphone

private struct MacMicCard: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var mic: MacMicRecorder
    @ObservedObject var store: SettingsStore

    private var enabledBinding: Binding<Bool> {
        Binding(get: { store.settings.macMicEnabled }, set: { enabled in
            model.setMacMicEnabled(enabled)
        })
    }

    private var levelText: String {
        guard mic.isRecording else { return "Off" }
        guard mic.level.isFinite else { return "Silent" }
        return String(format: "%.0f dB", Double(mic.level))
    }

    var body: some View {
        EarshotCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: enabledBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use this Mac's microphone")
                            .font(.headline)
                        Text("Desk mode: records in \(store.settings.segmentSeconds)-second segments while you're at your Mac without the watch.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                HStack(spacing: 10) {
                    Image(systemName: mic.isRecording ? "mic.fill" : "mic.slash")
                        .foregroundStyle(mic.isRecording ? Color.red : Color.secondary)
                        .frame(width: 18)
                    EarshotLevelMeter(level: mic.level, active: mic.isRecording)
                        .frame(maxWidth: 280)
                    Text(levelText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                }
                if let error = mic.lastError {
                    EarshotNotice(error, symbol: "exclamationmark.triangle.fill", tint: .red,
                                  actionTitle: "Microphone Settings") {
                        EarshotSystemSettings.openPrivacyPane("Privacy_Microphone")
                    }
                }
                Text("Tell the people around you that Earshot is listening, and turn it off when asked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
