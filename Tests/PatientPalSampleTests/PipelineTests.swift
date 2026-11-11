import XCTest
@testable import PatientPalSample

/// Captures stage calls to check that rejected requests never reach generation.
private actor StubModel: ContextModel {
    var ids: [String]
    var summary: String
    var draft: String
    var decision: ScreenDecision
    var calls: [String] = []
    var receivedContext: AnswerContext?
    var failScreen: Bool

    init(ids: [String] = ["v1"], summary: String = "", draft: String = "A draft.",
         decision: ScreenDecision = .allow, failScreen: Bool = false) {
        self.ids = ids
        self.summary = summary
        self.draft = draft
        self.decision = decision
        self.failScreen = failScreen
    }

    func selectVisits(question: String, visits: [VisitRecord]) async throws -> [String] {
        calls.append("select")
        return ids
    }
    func summarizeProfile(question: String, profile: ProfileContext) async throws -> String {
        calls.append("profile")
        return summary
    }
    func draftAnswer(question: String, context: AnswerContext) async throws -> String {
        calls.append("draft")
        receivedContext = context
        return draft
    }
    func screen(question: String, draft: String, context: AnswerContext) async throws -> ScreenDecision {
        calls.append("screen")
        if failScreen { throw PipelineError.modelUnavailable }
        return decision
    }
}

@MainActor
final class PipelineTests: XCTestCase {
    private let visits = [
        VisitRecord(id: "v1", date: "2025-01-01", summary: "Synthetic first note."),
        VisitRecord(id: "v2", date: "2025-01-02", summary: "Synthetic second note.")
    ]
    private let profile = ProfileContext(facts: [])

    func testSelectedContextUsesOriginalRecordsAndPreservesDraft() async throws {
        let model = StubModel(ids: ["v2"], draft: "Exact draft, including punctuation!")
        let result = try await ContextPipeline(model: model).answer(
            question: "Which note?", visits: visits, profile: profile
        )
        let context = await model.receivedContext
        let calls = await model.calls
        XCTAssertEqual(context?.visits, [visits[1]])
        XCTAssertEqual(result.selectedVisitIDs, ["v2"])
        XCTAssertEqual(result.text, "Exact draft, including punctuation!")
        XCTAssertEqual(result.outcome, .answered)
        XCTAssertEqual(calls, ["select", "profile", "draft", "screen"])
    }

    func testInventedDuplicateAndExcessSelectionsAreRejected() async throws {
        for ids in [["missing"], ["v1", "v1"], ["v1", "v2", "v3", "v4"]] {
            let model = StubModel(ids: ids)
            do {
                _ = try await ContextPipeline(model: model).answer(
                    question: "Question", visits: visits, profile: profile
                )
                XCTFail("Invalid selection must not reach answer generation")
            } catch { XCTAssertEqual(error as? PipelineError, .invalidSelection) }
            let calls = await model.calls
            XCTAssertEqual(calls, ["select"])
        }
    }

    func testEmptyContextSkipsDraftAndScreen() async throws {
        let model = StubModel(ids: [], summary: "  \n ")
        let result = try await ContextPipeline(model: model).answer(
            question: "Unknown question", visits: visits, profile: profile
        )
        XCTAssertEqual(result.outcome, .noContext)
        let calls = await model.calls
        XCTAssertEqual(calls, ["select", "profile"])
    }

    func testProfileOnlyContextCanReachAnswerStage() async throws {
        let model = StubModel(ids: [], summary: "Synthetic preference: written reminders.")
        let result = try await ContextPipeline(model: model).answer(
            question: "Reminder preference?", visits: [], profile: profile
        )
        XCTAssertEqual(result.outcome, .answered)
        XCTAssertEqual(result.selectedVisitIDs, [])
    }

    func testBlockedResponseNeverReturnsDraft() async throws {
        let model = StubModel(draft: "This draft must not escape.", decision: .block)
        let result = try await ContextPipeline(model: model).answer(
            question: "Question", visits: visits, profile: profile
        )
        XCTAssertEqual(result.outcome, .blocked)
        XCTAssertEqual(result.text, ContextPipeline<StubModel>.refusal)
        XCTAssertFalse(result.text.contains("escape"))
    }

    func testScreenFailurePropagatesInsteadOfReleasingDraft() async throws {
        let model = StubModel(failScreen: true)
        do {
            _ = try await ContextPipeline(model: model).answer(
                question: "Question", visits: visits, profile: profile
            )
            XCTFail("An unsuccessful screen must not return an answer")
        } catch { XCTAssertEqual(error as? PipelineError, .modelUnavailable) }
    }

    func testBlankQuestionRejectedBeforeAnyModelCall() async throws {
        let model = StubModel()
        do {
            _ = try await ContextPipeline(model: model).answer(
                question: " \n ", visits: visits, profile: profile
            )
            XCTFail("Expected empty question error")
        } catch { XCTAssertEqual(error as? PipelineError, .emptyQuestion) }
        let calls = await model.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testDuplicateSourceIDsRejectedBeforeAnyModelCall() async throws {
        let model = StubModel()
        do {
            _ = try await ContextPipeline(model: model).answer(
                question: "Question", visits: [visits[0], visits[0]], profile: profile
            )
            XCTFail("Source IDs must be unique")
        } catch { XCTAssertEqual(error as? PipelineError, .invalidRecordIDs) }
        let calls = await model.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testOversizedInputRejectedBeforeModelCall() async throws {
        let model = StubModel()
        do {
            _ = try await ContextPipeline(model: model).answer(
                question: String(repeating: "x", count: 1_001), visits: visits, profile: profile
            )
            XCTFail("Expected budget error")
        } catch { XCTAssertEqual(error as? PipelineError, .inputTooLarge) }
        let calls = await model.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testEmptyDraftDoesNotReachScreen() async throws {
        let model = StubModel(draft: " \n ")
        do {
            _ = try await ContextPipeline(model: model).answer(
                question: "Question", visits: visits, profile: profile
            )
            XCTFail("Expected empty draft error")
        } catch { XCTAssertEqual(error as? PipelineError, .emptyDraft) }
        let calls = await model.calls
        XCTAssertEqual(calls, ["select", "profile", "draft"])
    }

    func testCancelledTaskMakesNoModelCalls() async throws {
        let model = StubModel()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ContextPipeline(model: model).answer(
                question: "Question", visits: visits, profile: profile
            )
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
        let calls = await model.calls
        XCTAssertTrue(calls.isEmpty)
    }
}
