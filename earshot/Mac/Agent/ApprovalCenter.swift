//  ApprovalCenter.swift
//  Human-in-the-loop approvals for agent actions. A request is shown in the Mac
//  UI (`pending`) and optionally on the watch as an `.approval` prompt; the
//  caller suspends until the user decides, the request times out, or the
//  calling task is cancelled. Every request resolves exactly once.

import Foundation
import Combine

@MainActor
final class ApprovalCenter: ObservableObject {
    @Published private(set) var pending: [ApprovalRequest] = []

    private enum Outcome {
        case approved, denied, timedOut, cancelled

        var approved: Bool { self == .approved }

        var label: String {
            switch self {
            case .approved: return "approved"
            case .denied: return "denied"
            case .timedOut: return "timed out"
            case .cancelled: return "cancelled"
            }
        }
    }

    private static let approveChoice = PromptChoice(id: "approve", title: "Approve")
    private static let denyChoice = PromptChoice(id: "deny", title: "Deny")

    private let db: Database
    /// Callers waiting for a decision, by approval id.
    private var waiters: [String: CheckedContinuation<Bool, Never>] = [:]
    /// Timeout timers, by approval id.
    private var timers: [String: Task<Void, Never>] = [:]
    /// Decisions that arrived before the caller started waiting (resolved in between).
    private var earlyDecisions: [String: Bool] = [:]

    init(db: Database) {
        self.db = db
    }

    /// Shows the request in the Mac UI (and as a watch .approval prompt when sendToWatch).
    /// Returns true if approved; false when denied, after `timeout`, or when the calling task is cancelled.
    func requestApproval(title: String, detail: String, risk: RiskLevel, sendToWatch: Bool, timeout: TimeInterval) async -> Bool {
        let id = UUID().uuidString
        let now = Date()
        let limit = (timeout.isFinite && timeout > 0) ? max(timeout, 5) : 600
        let cleanTitle = title.trimmed.isEmpty ? "Approve an action" : title.trimmed

        var promptID: String?
        if sendToWatch {
            var prompt = StoredPrompt.make(kind: .approval,
                                           title: cleanTitle.clipped(80),
                                           body: detail.trimmed.clipped(180),
                                           choices: [ApprovalCenter.approveChoice, ApprovalCenter.denyChoice],
                                           allowsFreeText: false,
                                           allowsVoice: false,
                                           priority: 4,
                                           status: .pending,
                                           rationale: "Earshot needs your approval for a \(risk.rawValue)-risk action on your Mac.",
                                           relatedID: id,
                                           expiresAt: now.addingTimeInterval(limit))
            prompt.releasedAt = now
            db.upsertPrompt(prompt)
            EarshotEvents.post(.prompts)
            promptID = prompt.id
        }

        let request = ApprovalRequest(id: id, title: cleanTitle, detail: detail, risk: risk,
                                      createdAt: now, promptID: promptID)
        pending.append(request)
        Log.info("ApprovalCenter: waiting for approval \(id) (\(risk.rawValue) risk, watch: \(sendToWatch)): \(cleanTitle.clipped(80))")

        let approved = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                if let decided = self.earlyDecisions.removeValue(forKey: id) {
                    continuation.resume(returning: decided)
                    return
                }
                self.waiters[id] = continuation
                let nanoseconds = UInt64(min(limit, 86_400) * 1_000_000_000)
                self.timers[id] = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: nanoseconds)
                    guard !Task.isCancelled else { return }
                    self.finish(id: id, outcome: .timedOut)
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.finish(id: id, outcome: .cancelled)
            }
        }
        return approved
    }

    /// Resolves a pending request (Mac UI button or watch answer). Later calls for the same id are ignored.
    func resolve(id: String, approved: Bool) {
        finish(id: id, outcome: approved ? .approved : .denied)
    }

    nonisolated static func isAutoApproved(_ risk: RiskLevel, settings: AppSettings) -> Bool {
        switch risk {
        case .low: return settings.autoApproveLowRisk
        case .medium: return settings.autoApproveMediumRisk
        case .high: return false
        }
    }

    // MARK: - Private

    private func finish(id: String, outcome: Outcome) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else {
            // Unknown or already resolved: resolving twice must never resume a continuation twice.
            return
        }
        let request = pending.remove(at: index)
        timers.removeValue(forKey: id)?.cancel()
        if let promptID = request.promptID {
            closeWatchPrompt(promptID, outcome: outcome)
        }
        Log.info("ApprovalCenter: approval \(id) \(outcome.label): \(request.title.clipped(80))")

        if let waiter = waiters.removeValue(forKey: id) {
            waiter.resume(returning: outcome.approved)
        } else {
            earlyDecisions[id] = outcome.approved
        }
    }

    /// Marks the watch prompt as decided unless the watch already answered it.
    private func closeWatchPrompt(_ promptID: String, outcome: Outcome) {
        guard var prompt = db.prompt(id: promptID) else { return }
        switch prompt.status {
        case .queued, .pending, .delivered, .awaitingVoice:
            break
        case .answered, .dismissed, .expired:
            return
        }
        let now = Date()
        switch outcome {
        case .approved:
            prompt.status = .answered
            prompt.answerChoiceID = ApprovalCenter.approveChoice.id
            prompt.answerText = prompt.answerText ?? ApprovalCenter.approveChoice.title
            prompt.answeredAt = now
        case .denied:
            prompt.status = .answered
            prompt.answerChoiceID = ApprovalCenter.denyChoice.id
            prompt.answerText = prompt.answerText ?? ApprovalCenter.denyChoice.title
            prompt.answeredAt = now
        case .timedOut:
            prompt.status = .expired
        case .cancelled:
            prompt.status = .dismissed
            prompt.answeredAt = now
        }
        db.upsertPrompt(prompt)
        EarshotEvents.post(.prompts)
    }
}
