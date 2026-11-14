//  EarshotMacApp.swift
//  App entry: the main window, a menu bar extra with status and quick actions,
//  and the Settings scene. The app delegate starts and stops `AppModel`.

import SwiftUI
import AppKit

@main
struct EarshotMacApp: App {
    @NSApplicationDelegateAdaptor(EarshotAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Earshot", id: "main") {
            EarshotRootView()
                .environmentObject(AppModel.shared)
                .frame(minWidth: 920, minHeight: 600)
        }
        .defaultSize(width: 1220, height: 780)
        .commands {
            EarshotCommands(model: AppModel.shared)
        }

        MenuBarExtra {
            EarshotMenuBarView()
                .environmentObject(AppModel.shared)
        } label: {
            EarshotMenuBarLabel(model: AppModel.shared)
        }
        .menuBarExtraStyle(.window)

        Settings {
            EarshotSettingsView()
                .environmentObject(AppModel.shared)
                .frame(minWidth: 680, minHeight: 560)
        }
    }
}

// MARK: - App delegate

@MainActor
private final class EarshotAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // EarshotTests is hosted by this app. Under XCTest, don't start the services (HTTP server,
        // transcription of pending segments, desk mode, permission prompts, the minute timer that
        // calls Claude), which would otherwise run against the real archive next to the user's
        // everyday Earshot. The unit tests only exercise pure helpers.
        if EarshotAppDelegate.isRunningUnitTests {
            Log.info("Earshot: hosted by XCTest; services not started.")
            return
        }
        AppModel.shared.start()
    }

    private static var isRunningUnitTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }

    /// Keep running in the menu bar (the watch keeps uploading) when the window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.shutdown()
    }
}

// MARK: - Menu bar label

private struct EarshotMenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Image(systemName: model.serverRunning ? "waveform" : "waveform.badge.exclamationmark")
            .accessibilityLabel(model.serverRunning ? "Earshot" : "Earshot: server not running")
    }
}

// MARK: - Menu commands

private struct EarshotCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Import Audio…") {
                model.presentImportPanel()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Export Everything…") {
                model.exportAll()
            }
        }

        CommandMenu("Earshot") {
            Button("Analyze Now") {
                model.analyzeNow()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Generate Today's Digest") {
                model.generateDigest(weekly: false)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Generate Weekly Review") {
                model.generateDigest(weekly: true)
            }

            Divider()

            Button("Toggle Mac Microphone") {
                model.setMacMicEnabled(!model.settings.settings.macMicEnabled)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }

        CommandMenu("Go") {
            ForEach(Array(AppModel.SidebarItem.allCases.enumerated()), id: \.element) { index, item in
                Button(item.title) {
                    model.sidebarSelection = item
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }
    }
}
