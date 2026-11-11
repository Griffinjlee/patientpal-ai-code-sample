# PatientPal — On-Device AI Context Pipeline (Code Sample)

**Swift · Apple Foundation Models · Structured generation · Context selection**

This is a **sanitized, shortened adaptation** of the `modelQuery(input:)` workflow in the PatientPal iOS app, developed as a collaborative project. The full application's source repository is private. This sample shows the architectural approach without including user records, credentials, application configuration, or proprietary supporting components.

## What it demonstrates

1. Encode stored visit summaries and profile information as structured JSON.
2. Use on-device structured generation to select up to three relevant visits for a question.
3. Summarize only the relevant patient-profile context.
4. Compose an answer grounded in that selected context.
5. Pass the draft through an additional model-based screen intended to suppress unsupported medical claims.

The screening stage is **not independently validated** and does not make this prototype suitable for clinical use. These steps are representative of the original application; the data-transfer objects (`VisitDTO`, `UserProfileDTO`) belong to the private application and are intentionally omitted. This is a code sample, not a standalone buildable app.

## Representative Swift implementation

```swift
import Foundation
import FoundationModels

@Generable
struct ProfileSummary: Codable {
    let summary: String
}

// Adapted from PatientPal/LLMViews/Automating.swift, modelQuery(input:).
// VisitDTO and UserProfileDTO are private application types.
func respondToQuestion(
    _ question: String,
    visits: [VisitDTO],
    profiles: [UserProfileDTO]
) async throws -> String {
    let model = SystemLanguageModel.default

    // Stage 1: Select structured records that matter to the question.
    let visitJSON = String(
        data: try JSONEncoder().encode(visits), encoding: .utf8
    ) ?? "[]"
    let visitSession = LanguageModelSession(
        model: model,
        instructions: "Select only relevant records. Do not invent information."
    )
    let matched = try await visitSession.respond(
        to: "Question: \(question)\nVisits (JSON): \(visitJSON)\nReturn at most three relevant visits.",
        generating: [VisitDTO].self
    )
    let relevantVisitJSON = String(
        data: try JSONEncoder().encode(matched.content), encoding: .utf8
    ) ?? "[]"

    // Stage 2: Extract the minimal relevant profile information.
    let profileJSON = String(
        data: try JSONEncoder().encode(profiles), encoding: .utf8
    ) ?? "[]"
    let profileSession = LanguageModelSession(
        model: model,
        instructions: "Summarize only profile facts relevant to the question."
    )
    let profile = try await profileSession.respond(
        to: "Question: \(question)\nProfile (JSON): \(profileJSON)",
        generating: ProfileSummary.self
    )

    // Stage 3: Generate an answer using selected context, not the full database.
    let answerSession = LanguageModelSession(
        model: model,
        instructions: "Answer concisely using the provided records."
    )
    let draft = try await answerSession.respond(to: """
        Question: \(question)
        Relevant visits: \(relevantVisitJSON)
        Relevant profile: \(profile.content.summary)
        """)

    // Stage 4: Secondary screening; this is not a clinical safety guarantee.
    let screenSession = LanguageModelSession(
        model: model,
        instructions: """
            Review the drafted response. If it contains unsupported medical
            advice or diagnoses, replace it with a refusal. Otherwise,
            preserve the answer verbatim.
            """
    )
    let screened = try await screenSession.respond(
        to: "Draft response: \(draft.content)"
    )
    return screened.content
}
```

## Engineering considerations

- **Separation of responsibilities:** retrieval, profile-context extraction, response generation, and screening use separate model sessions.
- **Typed intermediates:** generated visits and profile summaries have explicitly constrained output types.
- **Context minimization:** the answer model receives a selected set of records rather than the entire visit history.
- **On-device processing:** the pipeline is based on Apple's Foundation Models, with no external model API in this code path.
- **Limitations:** model-selected context can omit relevant details; screening can make mistakes; clinical safety and privacy compliance require separate validation and security review.

**Provenance:** Adapted and abbreviated from a collaborative PatientPal project for a software internship application. The original implementation's source and models remain private. No patient data appears in this sample.
