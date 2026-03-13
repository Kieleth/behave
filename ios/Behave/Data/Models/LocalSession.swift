import Foundation
import SwiftData

/// Local session record for offline-first storage.
@Model
final class LocalSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var postureScore: Double?
    var expressionScore: Double?
    var habitScore: Double?
    var speechScore: Double?
    var overallScore: Double?
    var synced: Bool

    @Relationship(deleteRule: .cascade)
    var events: [LocalEvent] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        synced: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.synced = synced
    }

    func end(scores: (posture: Double, expression: Double, habit: Double, speech: Double)) {
        self.endedAt = Date()
        self.postureScore = scores.posture
        self.expressionScore = scores.expression
        self.habitScore = scores.habit
        self.speechScore = scores.speech
        self.overallScore = (scores.posture + scores.expression + scores.habit + scores.speech) / 4
    }
}
