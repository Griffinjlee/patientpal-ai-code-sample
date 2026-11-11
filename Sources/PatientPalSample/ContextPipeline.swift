// Architecture adapted from Automating.swift; implementation refactored for
// this sample with AI assistance. Validation and ID selection are new additions.
import Foundation

public struct ContextPipeline<Model: ContextModel>: Sendable {
    public static var refusal: String {
        "This prototype cannot provide a grounded response to that question."
    }

    private let model: Model
    public init(model: Model) { self.model = model }

    /// No record contents are logged. The final result exposes selected IDs so
    /// a caller can inspect provenance without returning the entire database.
    public func answer(
        question: String,
        visits: [VisitRecord],
        profile: ProfileContext
    ) async throws -> PipelineResult {
        try Task.checkCancellation()
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { throw PipelineError.emptyQuestion }
        guard visits.allSatisfy({ !$0.id.isEmpty }),
              Set(visits.map(\.id)).count == visits.count else {
            throw PipelineError.invalidRecordIDs
        }
        // A sample-specific character budget, NOT a model-token guarantee.
        guard question.count <= 1_000,
              try json(visits).count + json(profile).count <= 6_000 else {
            throw PipelineError.inputTooLarge
        }

        // Stage 1: ask for IDs, then recover records from the original input.
        // Never trust a generated copy of a record as source-of-truth data.
        let ids = try await model.selectVisits(question: question, visits: visits)
        try Task.checkCancellation()
        let records = Dictionary(uniqueKeysWithValues: visits.map { ($0.id, $0) })
        guard ids.count <= 3, Set(ids).count == ids.count,
              ids.allSatisfy({ records[$0] != nil }) else {
            throw PipelineError.invalidSelection
        }
        let selected = ids.compactMap { records[$0] }

        // Stage 2: isolate profile extraction from answer generation.
        let summary = try await model.summarizeProfile(question: question, profile: profile)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try Task.checkCancellation()
        guard summary.count <= 2_000 else { throw PipelineError.inputTooLarge }
        if selected.isEmpty && summary.isEmpty {
            return PipelineResult(
                text: "No relevant information was found in the supplied records.",
                selectedVisitIDs: [], outcome: .noContext
            )
        }

        // Stage 3: the answer stage receives selected context only.
        let context = AnswerContext(visits: selected, profileSummary: summary)
        let draft = try await model.draftAnswer(question: question, context: context)
        try Task.checkCancellation()
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyDraft
        }
        guard draft.count <= 4_000 else { throw PipelineError.inputTooLarge }

        // Stage 4: a block is a fixed refusal; an allow preserves the draft.
        // A model judgment is not a validated clinical-safety mechanism.
        let decision = try await model.screen(question: question, draft: draft, context: context)
        try Task.checkCancellation()
        switch decision {
        case .allow:
            return PipelineResult(text: draft, selectedVisitIDs: ids, outcome: .answered)
        case .block:
            return PipelineResult(text: Self.refusal, selectedVisitIDs: ids, outcome: .blocked)
        }
    }
}
