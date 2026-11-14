//  DigestsView.swift
//  Daily digests and weekly reviews written by the AI, rendered from Markdown.

import SwiftUI
import AppKit

struct EarshotDigestsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            DigestList()
                .frame(width: 260)
            Divider()
            DigestDetailPane()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Digests")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.isGeneratingDigest {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    model.generateDigest(weekly: false)
                } label: {
                    Label("Generate Today's Digest", systemImage: "sun.max")
                }
                .disabled(model.isGeneratingDigest)
                .help("Summarise today: highlights, commitments, open loops and goals")
                Button {
                    model.generateDigest(weekly: true)
                } label: {
                    Label("Weekly Review", systemImage: "calendar")
                }
                .disabled(model.isGeneratingDigest)
                .help("Review the last seven days")
            }
        }
        .onAppear {
            if model.selectedDigestID == nil {
                model.selectedDigestID = model.digests.first?.day
            }
        }
    }
}

private struct DigestList: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        List(selection: $model.selectedDigestID) {
            ForEach(model.digests) { digest in
                DigestRow(digest: digest)
                    .tag(digest.day)
            }
        }
        .listStyle(.inset)
        .overlay {
            if model.digests.isEmpty {
                Text("No digests yet")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DigestRow: View {
    let digest: Digest

    private var preview: String {
        for line in digest.markdown.components(separatedBy: "\n") {
            let text = line.trimmingCharacters(in: CharacterSet(charactersIn: "#*->_ ").union(.whitespaces))
            if text.count > 12 { return text }
        }
        return ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: EarshotFormat.isWeeklyDigest(digest.day) ? "calendar" : "sun.max")
                .foregroundStyle(EarshotFormat.isWeeklyDigest(digest.day) ? Color.purple : Color.orange)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(EarshotFormat.digestTitle(digest.day))
                    .font(.body.weight(.medium))
                if !preview.isEmpty {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct DigestDetailPane: View {
    @EnvironmentObject var model: AppModel

    private var selected: Digest? {
        guard let id = model.selectedDigestID else { return nil }
        return model.digests.first { $0.day == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.digestError {
                EarshotNotice("Couldn't generate the digest: \(error)", symbol: "exclamationmark.triangle.fill", tint: .red)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
            if let digest = selected {
                DigestDocument(digest: digest)
            } else if model.isGeneratingDigest {
                ProgressView("Writing your digest…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label(model.digests.isEmpty ? "No digests yet" : "Select a digest", systemImage: "doc.text")
                } description: {
                    Text("Every evening Earshot writes a digest of your day: what happened, what you promised, open loops, progress on your goals and a question to reflect on.")
                } actions: {
                    HStack(spacing: 10) {
                        Button("Generate Today's Digest") {
                            model.generateDigest(weekly: false)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Weekly Review") {
                            model.generateDigest(weekly: true)
                        }
                    }
                    .disabled(model.isGeneratingDigest)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct DigestDocument: View {
    @EnvironmentObject var model: AppModel
    let digest: Digest

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(EarshotFormat.digestTitle(digest.day))
                            .font(.largeTitle.weight(.bold))
                        Text("Written \(digest.createdAt.shortText)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !EarshotFormat.isWeeklyDigest(digest.day), let day = EarshotFormat.date(fromDayKey: digest.day) {
                        Button {
                            model.show(date: day)
                        } label: {
                            Label("Open Day", systemImage: "sun.max")
                        }
                    }
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(digest.markdown, forType: .string)
                        model.showBanner(.success, "Copied the digest as Markdown.")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                Divider()
                EarshotMarkdownView(digest.markdown)
            }
            .padding(32)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
