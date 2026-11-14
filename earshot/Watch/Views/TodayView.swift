//  TodayView.swift
//  Earshot (watchOS)
//
//  Today at a glance, as summarised by the Mac.

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var recorder: AudioCapture

    var body: some View {
        let today = store.today
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: today.headline.isEmpty ? emptyHeadline : today.headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    StatTile(value: "\(today.wordsToday)", label: "words",
                             systemImage: "text.quote", tint: .blue)
                    StatTile(value: EarshotFormat.minutes(today.minutesRecorded), label: "on Mac",
                             systemImage: "waveform", tint: .red)
                }
                HStack(spacing: 6) {
                    StatTile(value: "\(today.openTasks)", label: "open tasks",
                             systemImage: "checklist", tint: .orange)
                    StatTile(value: EarshotFormat.duration(recorder.todayTotalSeconds), label: "on watch",
                             systemImage: "applewatch", tint: .green)
                }

                if !today.highlights.isEmpty {
                    Text("Highlights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    ForEach(Array(today.highlights.enumerated()), id: \.offset) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .padding(.top, 3)
                            Text(verbatim: entry.element)
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let next = today.nextUp, !next.isEmpty {
                    Text("Next up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    Label {
                        Text(verbatim: next)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    Task { await store.syncNow() }
                } label: {
                    Label(syncTitle, systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isSyncing || store.pairingStatus != .paired)
                .padding(.top, 4)

                TimelineView(.everyMinute) { context in
                    Text(verbatim: footer(now: context.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle("Today")
        .containerBackground(Color.green.gradient, for: .tabView)
    }

    private var syncTitle: String {
        store.isSyncing ? "Syncing…" : "Sync now"
    }

    private var emptyHeadline: String {
        store.pairingStatus == .paired
            ? "No summary yet — your Mac writes one as the day goes on."
            : "Pair with your Mac to see your day here."
    }

    private func footer(now: Date) -> String {
        if let error = store.lastSyncError {
            return error
        }
        return "Updated \(EarshotFormat.relative(store.lastSyncAt, now: now))"
    }
}
