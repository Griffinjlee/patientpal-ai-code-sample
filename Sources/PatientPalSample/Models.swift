// Public-sample types added with AI assistance; see PROVENANCE.md.
import Foundation

/// Deliberately small schema: no names, contacts, insurance, audio, or identifiers
/// from the private application's persistent database are exported.
public struct VisitRecord: Codable, Sendable, Equatable {
    public let id: String
    public let date: String
    public let summary: String

    public init(id: String, date: String, summary: String) {
        self.id = id
        self.date = date
        self.summary = summary
    }
}

public struct ProfileContext: Codable, Sendable, Equatable {
    public let facts: [String]

    public init(facts: [String]) {
        self.facts = facts
    }
}

public struct AnswerContext: Codable, Sendable, Equatable {
    public let visits: [VisitRecord]
    public let profileSummary: String
}

public struct PipelineResult: Sendable, Equatable {
    public enum Outcome: Sendable { case answered, noContext, blocked }
    public let text: String
    public let selectedVisitIDs: [String]
    public let outcome: Outcome
}

public enum PipelineError: Error, Equatable {
    case emptyQuestion
    case invalidRecordIDs
    case inputTooLarge
    case invalidSelection
    case emptyDraft
    case modelUnavailable
}

/// A typed decision avoids treating arbitrary screening output as permission.
public enum ScreenDecision: Sendable {
    case allow
    case block
}

/// These boundaries follow the original project's four model stages.
/// Injection makes orchestration testable without downloading or invoking a model.
public protocol ContextModel: Sendable {
    func selectVisits(question: String, visits: [VisitRecord]) async throws -> [String]
    func summarizeProfile(question: String, profile: ProfileContext) async throws -> String
    func draftAnswer(question: String, context: AnswerContext) async throws -> String
    func screen(question: String, draft: String, context: AnswerContext) async throws -> ScreenDecision
}

/// Compact, deterministic JSON for prompt construction; errors propagate.
func json<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}
