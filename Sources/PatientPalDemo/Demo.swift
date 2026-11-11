// Newly written synthetic fixture/demo, not historical application code.
import PatientPalSample

/// Scripted responses exercise plumbing; this is not a language model or retriever.
struct ScriptedDemoModel: ContextModel {
    func selectVisits(question: String, visits: [VisitRecord]) async throws -> [String] {
        ["demo-visit-1"]
    }
    func summarizeProfile(question: String, profile: ProfileContext) async throws -> String {
        ""
    }
    func draftAnswer(question: String, context: AnswerContext) async throws -> String {
        "The synthetic record says to bring a list of questions. [demo-visit-1]"
    }
    func screen(question: String, draft: String, context: AnswerContext) async throws -> ScreenDecision {
        .allow
    }
}

@main
struct Demo {
    static func main() async throws {
        // Invented scheduling notes; no real person or medical record is represented.
        let visits = [
            VisitRecord(id: "demo-visit-1", date: "2025-01-01",
                        summary: "Synthetic appointment preparation: bring a list of questions."),
            VisitRecord(id: "demo-visit-2", date: "2025-01-02",
                        summary: "Synthetic scheduling note: appointment moved to the afternoon.")
        ]
        let profile = ProfileContext(facts: ["Synthetic preference: written appointment reminders."])
        let question = "What should I bring to the appointment?"
        let result: PipelineResult
        if CommandLine.arguments.contains("--live") {
            result = try await ContextPipeline(model: AppleContextModel()).answer(
                question: question, visits: visits, profile: profile
            )
        } else {
            print("SCRIPTED DEMO — no language model is invoked.")
            result = try await ContextPipeline(model: ScriptedDemoModel()).answer(
                question: question, visits: visits, profile: profile
            )
        }
        print("Outcome: \(result.outcome)")
        print("Selected IDs: \(result.selectedVisitIDs.joined(separator: ", "))")
        print(result.text)
    }
}
