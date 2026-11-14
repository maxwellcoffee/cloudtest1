//  GoalsView.swift
//  Goals the user is working toward: list, editor, progress notes, and
//  "ask me about this goal" check-ins delivered to the watch.

import SwiftUI

struct EarshotGoalsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedID: String? = nil
    @State private var showNewGoal = false

    var body: some View {
        HStack(spacing: 0) {
            GoalList(selectedID: $selectedID)
                .frame(width: 280)
            Divider()
            if let goal = model.goals.first(where: { $0.id == selectedID }) {
                GoalDetail(goal: goal)
                    .id(goal.id)
            } else {
                ContentUnavailableView {
                    Label(model.goals.isEmpty ? "No goals yet" : "Select a goal", systemImage: "flag")
                } description: {
                    Text("Goals give Earshot context: it notices progress in what you say, notes it here, and checks in on your watch now and then.")
                } actions: {
                    Button("New Goal") {
                        showNewGoal = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewGoal = true
                } label: {
                    Label("New Goal", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewGoal) {
            NewGoalSheet { title, why in
                if let goal = model.createGoal(title: title, why: why) {
                    selectedID = goal.id
                }
            }
        }
        .onAppear {
            if selectedID == nil {
                selectedID = model.goals.first(where: { $0.status == .active })?.id ?? model.goals.first?.id
            }
        }
    }
}

private enum GoalText {
    static func label(_ status: GoalStatus) -> String {
        switch status {
        case .active: return "Active"
        case .paused: return "Paused"
        case .done: return "Done"
        }
    }

    static func symbol(_ status: GoalStatus) -> String {
        switch status {
        case .active: return "flag.fill"
        case .paused: return "pause.circle"
        case .done: return "checkmark.circle.fill"
        }
    }

    static func promptStatus(_ status: PromptStatus) -> String {
        switch status {
        case .queued: return "Waiting"
        case .pending, .delivered: return "On your watch"
        case .awaitingVoice: return "Listening"
        case .answered: return "Answered"
        case .dismissed: return "Skipped"
        case .expired: return "Expired"
        }
    }

    static func color(_ status: GoalStatus) -> Color {
        switch status {
        case .active: return .green
        case .paused: return .orange
        case .done: return .secondary
        }
    }
}

// MARK: - List

private struct GoalList: View {
    @EnvironmentObject var model: AppModel
    @Binding var selectedID: String?

    var body: some View {
        List(selection: $selectedID) {
            ForEach(GoalStatus.allCases, id: \.self) { status in
                let goals = model.goals.filter { $0.status == status }
                if !goals.isEmpty {
                    Section(GoalText.label(status)) {
                        ForEach(goals) { goal in
                            GoalRow(goal: goal)
                                .tag(goal.id)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

private struct GoalRow: View {
    let goal: Goal

    private var subtitle: String {
        if let checkIn = goal.lastCheckIn {
            return "Last progress \(checkIn.relativeText)"
        }
        return "Added \(goal.createdAt.relativeText)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: GoalText.symbol(goal.status))
                .foregroundStyle(GoalText.color(goal.status))
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if let why = goal.why.nilIfEmpty {
                    Text(why)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Detail

private struct GoalDetail: View {
    @EnvironmentObject var model: AppModel
    let goal: Goal
    @State var title: String
    @State var why: String
    @State var status: GoalStatus
    @State var newNote = ""
    @State var confirmDelete = false

    init(goal: Goal) {
        self.goal = goal
        _title = State(initialValue: goal.title)
        _why = State(initialValue: goal.why)
        _status = State(initialValue: goal.status)
    }

    private var hasChanges: Bool {
        title.trimmed != goal.title || why.trimmed != goal.why || status != goal.status
    }

    private var questionsAboutGoal: [StoredPrompt] {
        model.prompts.filter { $0.relatedID == goal.id && $0.kind != .approval }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                editor
                checkIn
                notes
                HStack {
                    Spacer()
                    Button("Delete Goal…", role: .destructive) {
                        confirmDelete = true
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Delete “\(goal.title)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteGoal(goal)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its progress notes are deleted too.")
        }
    }

    private var editor: some View {
        EarshotCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Goal", text: $title)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                TextField("Why it matters to you", text: $why, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...6)
                    .foregroundStyle(.secondary)
                Picker("Status", selection: $status) {
                    ForEach(GoalStatus.allCases, id: \.self) { value in
                        Text(GoalText.label(value)).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)
                HStack(spacing: 10) {
                    Button("Save") {
                        save()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges || title.trimmed.isEmpty)
                    Button("Revert") {
                        title = goal.title
                        why = goal.why
                        status = goal.status
                    }
                    .disabled(!hasChanges)
                    Spacer()
                    Text("Added \(goal.createdAt.shortText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var checkIn: some View {
        EarshotCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Check-ins", systemImage: "applewatch")
                    .font(.headline)
                Text("Earshot can ask you about this goal on your watch and keep track of what you say.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button {
                        model.askAboutGoal(goal, immediately: false)
                    } label: {
                        Label("Ask Me at a Good Moment", systemImage: "clock")
                    }
                    Button {
                        model.askAboutGoal(goal, immediately: true)
                    } label: {
                        Label("Ask Me Now", systemImage: "applewatch.radiowaves.left.and.right")
                    }
                }
                let recent = Array(questionsAboutGoal.prefix(3))
                if !recent.isEmpty {
                    Divider()
                    ForEach(recent) { prompt in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: prompt.status == .answered ? "checkmark.bubble" : "bubble.left")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prompt.body)
                                    .font(.callout)
                                    .lineLimit(2)
                                if let answer = prompt.answerText?.nilIfEmpty {
                                    Text("You: \(answer)")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(GoalText.promptStatus(prompt.status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var notes: some View {
        EarshotCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Progress notes", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                HStack(spacing: 8) {
                    TextField("Add a note about your progress…", text: $newNote)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addNote)
                    Button("Add", action: addNote)
                        .disabled(newNote.trimmed.isEmpty)
                }
                let sorted = goal.notes.sorted { $0.date > $1.date }
                if sorted.isEmpty {
                    Text("No notes yet. Earshot adds one when it hears you make progress.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(sorted.enumerated()), id: \.offset) { _, note in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.6))
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.text)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(note.date.shortText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func save() {
        guard let cleanTitle = title.nilIfEmpty else { return }
        var updated = model.goals.first(where: { $0.id == goal.id }) ?? goal
        updated.title = cleanTitle
        updated.why = why.trimmed
        updated.status = status
        model.saveGoal(updated)
        title = cleanTitle
        why = updated.why
    }

    private func addNote() {
        guard let text = newNote.nilIfEmpty else { return }
        model.addNote(text, to: goal)
        newNote = ""
    }
}

// MARK: - New goal

private struct NewGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    let onCreate: (String, String) -> Void
    @State var title = ""
    @State var why = ""

    init(onCreate: @escaping (String, String) -> Void) {
        self.onCreate = onCreate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New goal")
                .font(.headline)
            TextField("What do you want to achieve?", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Why does it matter to you? (optional)", text: $why, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            Text("Earshot uses this to notice progress and to ask better questions.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Add Goal") {
                    onCreate(title, why)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
