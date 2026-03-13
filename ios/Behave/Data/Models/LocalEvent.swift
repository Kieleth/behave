import Foundation
import SwiftData

/// A behavioral event detected during a session.
@Model
final class LocalEvent {
    var id: UUID
    var type: String          // "posture_violation", "nail_bite", "filler_word", etc.
    var timestamp: Date
    var severity: String      // "low", "medium", "high"
    var details: String       // JSON string for flexible data

    var session: LocalSession?

    init(
        type: String,
        severity: String = "medium",
        details: String = "{}",
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.type = type
        self.timestamp = timestamp
        self.severity = severity
        self.details = details
    }
}
