//  SettingsView.swift
//  Earshot (watchOS)
//
//  Pairing, connection test, recording settings (read-only; edited on the Mac),
//  storage and queue, unpair.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var queue: SegmentQueue
    @EnvironmentObject private var recorder: AudioCapture

    @State private var address = ""
    @State private var code = ""
    @State private var testResult: String? = nil
    @State private var isTesting = false
    @State private var confirmUnpair = false
    @State private var didLoadAddress = false

    var body: some View {
        List {
            macSection
            recordingSection
            storageSection
            if store.pairingStatus != .unpaired {
                Section {
                    Button(role: .destructive) {
                        confirmUnpair = true
                    } label: {
                        Label("Unpair", systemImage: "xmark.circle")
                    }
                } footer: {
                    Text("Queued audio stays on the watch until you pair again.")
                }
            }
            Section {
                LabeledContent("Version", value: store.appVersion)
                LabeledContent("Watch", value: store.deviceName)
                LabeledContent("Recorded today", value: EarshotFormat.duration(recorder.todayTotalSeconds))
                LabeledContent("Notifications", value: notificationStatus)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .containerBackground(Color.gray.gradient, for: .tabView)
        .onAppear {
            guard !didLoadAddress else { return }
            didLoadAddress = true
            address = store.macAddress
        }
        .confirmationDialog(Text(unpairTitle), isPresented: $confirmUnpair, titleVisibility: .visible) {
            Button("Unpair", role: .destructive) {
                store.unpair()
                code = ""
                testResult = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Sections

    private var macSection: some View {
        Section {
            if store.pairingStatus == .paired, let name = store.macName {
                LabeledContent("Paired with", value: name)
            } else if store.pairingStatus == .needsRepair {
                StatusText(text: "Your Mac no longer recognises this watch. Enter a new code to pair again.",
                           systemImage: "exclamationmark.triangle.fill", tint: .yellow)
            }

            TextField("Mac address", text: $address, prompt: Text("192.168.1.5"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Pairing code", text: $code, prompt: Text("6-digit code"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task {
                    await store.pair(address: address, code: code)
                    if store.pairingStatus == .paired { code = "" }
                }
            } label: {
                HStack {
                    if store.isPairing {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    }
                    Text(verbatim: store.pairingStatus == .paired ? "Pair again" : "Pair")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(store.isPairing || address.trimmingCharacters(in: .whitespaces).isEmpty || code.isEmpty)

            if let message = store.pairingMessage {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                isTesting = true
                testResult = nil
                Task {
                    testResult = await store.testConnection(address: address)
                    isTesting = false
                }
            } label: {
                HStack {
                    if isTesting {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    }
                    Text("Test connection")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isTesting)

            if let testResult {
                Text(verbatim: testResult)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Mac")
        } footer: {
            Text("Find the address and the code in Earshot on your Mac, under Devices.")
        }
    }

    private var recordingSection: some View {
        let settings = store.remoteSettings
        return Section {
            LabeledContent("Segment length", value: EarshotFormat.duration(Double(settings.segmentSeconds)))
            LabeledContent("Silence below", value: "\(Int(settings.silenceThresholdDB.rounded())) dB")
            LabeledContent("Skip silence", value: settings.skipSilentSegments ? "On" : "Off")
            LabeledContent("Stop at battery",
                           value: settings.lowBatteryStopLevel > 0
                               ? "\(Int((settings.lowBatteryStopLevel * 100).rounded()))%" : "Never")
        } header: {
            Text("Recording")
        } footer: {
            Text("Change these on your Mac; the watch picks them up at the next sync.")
        }
    }

    private var storageSection: some View {
        Section {
            LabeledContent("Queued audio", value: queueText)
            LabeledContent("Storage used", value: EarshotFormat.bytes(queue.queuedBytes))
            LabeledContent("Messages waiting", value: "\(queue.outboxCount)")
            LabeledContent("Last upload", value: EarshotFormat.relative(queue.lastUploadAt))
            if let error = queue.lastError {
                StatusText(text: error, systemImage: "exclamationmark.triangle", tint: .yellow)
            }
            Button {
                Task { await store.syncNow() }
            } label: {
                Label(uploadTitle, systemImage: "arrow.up.circle")
                    .frame(maxWidth: .infinity)
            }
            .disabled(store.pairingStatus != .paired || queue.isUploading)
        } header: {
            Text("Storage")
        }
    }

    // MARK: Text

    private var uploadTitle: String {
        queue.isUploading ? "Uploading…" : "Upload now"
    }

    private var queueText: String {
        let count = queue.queuedSegments
        return count == 1 ? "1 segment" : "\(count) segments"
    }

    private var unpairTitle: String {
        if let name = store.macName { return "Unpair from \(name)?" }
        return "Unpair this watch?"
    }

    private var notificationStatus: String {
        switch store.notificationsAllowed {
        case .some(true): return "On"
        case .some(false): return "Off"
        case .none: return "—"
        }
    }
}
