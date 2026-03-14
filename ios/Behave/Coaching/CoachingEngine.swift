import Foundation
import SwiftData

/// Rule-based coaching engine. Queries SwiftData for session history
/// and produces structured insights — no LLM required.
struct CoachingEngine {

    // MARK: - Session report

    struct SessionReport {
        let duration: TimeInterval
        let scores: ScoreBreakdown
        let events: [EventSummary]
        let comparison: Comparison?
        let tip: TipLibrary.Tip?
    }

    struct ScoreBreakdown {
        let posture: Double
        let expression: Double
        let habit: Double
        let speech: Double
        let overall: Double

        var worstBehavior: String {
            let all = [("posture", posture), ("expression", expression), ("habit", habit), ("speech", speech)]
            return all.min(by: { $0.1 < $1.1 })?.0 ?? "posture"
        }

        var bestBehavior: String {
            let all = [("posture", posture), ("expression", expression), ("habit", habit), ("speech", speech)]
            return all.max(by: { $0.1 < $1.1 })?.0 ?? "posture"
        }
    }

    struct EventSummary {
        let type: String
        let count: Int
        let firstOccurrence: Date
        let lastOccurrence: Date
    }

    struct Comparison {
        let previousAvgScore: Double
        let currentScore: Double
        let trend: Trend
        let message: String

        enum Trend { case improving, stable, declining }
    }

    /// Generate a report for the most recent session.
    static func reportForLastSession(context: ModelContext) -> SessionReport? {
        var descriptor = FetchDescriptor<LocalSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let session = try? context.fetch(descriptor).first,
              let endedAt = session.endedAt else { return nil }

        let duration = endedAt.timeIntervalSince(session.startedAt)
        let scores = ScoreBreakdown(
            posture: session.postureScore ?? 1,
            expression: session.expressionScore ?? 1,
            habit: session.habitScore ?? 1,
            speech: session.speechScore ?? 1,
            overall: session.overallScore ?? 1
        )

        // Summarize events by type
        let events = summarizeEvents(session.events)

        // Compare with recent history
        let comparison = compareWithHistory(currentScore: scores.overall, context: context)

        // Pick a relevant tip
        let tip = TipLibrary.tip(for: scores.worstBehavior)

        return SessionReport(
            duration: duration,
            scores: scores,
            events: events,
            comparison: comparison,
            tip: tip
        )
    }

    // MARK: - Pattern detection (cross-session)

    struct Pattern {
        let title: String
        let detail: String
        let icon: String
    }

    /// Detect patterns across recent sessions.
    static func detectPatterns(context: ModelContext) -> [Pattern] {
        var descriptor = FetchDescriptor<LocalSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 30
        guard let sessions = try? context.fetch(descriptor), sessions.count >= 3 else { return [] }

        var patterns: [Pattern] = []

        // 1. Time-of-day pattern
        if let timePattern = detectTimeOfDayPattern(sessions) {
            patterns.append(timePattern)
        }

        // 2. Improvement trend
        if let trend = detectImprovementTrend(sessions) {
            patterns.append(trend)
        }

        // 3. Worst behavior consistency
        if let worstPattern = detectConsistentWeakness(sessions) {
            patterns.append(worstPattern)
        }

        // 4. Session duration correlation
        if let durationPattern = detectDurationCorrelation(sessions) {
            patterns.append(durationPattern)
        }

        return patterns
    }

    // MARK: - Private helpers

    private static func summarizeEvents(_ events: [LocalEvent]) -> [EventSummary] {
        let grouped = Dictionary(grouping: events, by: \.type)
        return grouped.map { type, items in
            let sorted = items.sorted(by: { $0.timestamp < $1.timestamp })
            return EventSummary(
                type: type,
                count: items.count,
                firstOccurrence: sorted.first?.timestamp ?? Date(),
                lastOccurrence: sorted.last?.timestamp ?? Date()
            )
        }.sorted(by: { $0.count > $1.count })
    }

    private static func compareWithHistory(currentScore: Double, context: ModelContext) -> Comparison? {
        var descriptor = FetchDescriptor<LocalSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8  // compare with last 7 (skip current)
        guard let sessions = try? context.fetch(descriptor), sessions.count >= 2 else { return nil }

        let previous = Array(sessions.dropFirst())
        let avgScore = previous.compactMap(\.overallScore).reduce(0, +) / max(1, Double(previous.count))
        let diff = currentScore - avgScore

        let trend: Comparison.Trend
        let message: String

        if diff > 0.05 {
            trend = .improving
            message = String(format: "%.0f%% better than your recent average", diff * 100)
        } else if diff < -0.05 {
            trend = .declining
            message = String(format: "%.0f%% below your recent average", abs(diff) * 100)
        } else {
            trend = .stable
            message = "Consistent with your recent sessions"
        }

        return Comparison(previousAvgScore: avgScore, currentScore: currentScore, trend: trend, message: message)
    }

    private static func detectTimeOfDayPattern(_ sessions: [LocalSession]) -> Pattern? {
        let calendar = Calendar.current
        let morning = sessions.filter { calendar.component(.hour, from: $0.startedAt) < 12 }
        let afternoon = sessions.filter { calendar.component(.hour, from: $0.startedAt) >= 12 }

        guard morning.count >= 2, afternoon.count >= 2 else { return nil }

        let morningAvg = morning.compactMap(\.overallScore).reduce(0, +) / Double(morning.count)
        let afternoonAvg = afternoon.compactMap(\.overallScore).reduce(0, +) / Double(afternoon.count)
        let diff = abs(morningAvg - afternoonAvg)

        guard diff > 0.1 else { return nil }

        let better = morningAvg > afternoonAvg ? "morning" : "afternoon"
        let worse = morningAvg > afternoonAvg ? "afternoon" : "morning"
        let betterScore = max(morningAvg, afternoonAvg)
        let worseScore = min(morningAvg, afternoonAvg)

        return Pattern(
            title: "Time of day matters",
            detail: String(format: "Your %@ sessions average %.0f%% vs %.0f%% in the %@", better, betterScore * 100, worseScore * 100, worse),
            icon: "clock"
        )
    }

    private static func detectImprovementTrend(_ sessions: [LocalSession]) -> Pattern? {
        let scores = sessions.reversed().compactMap(\.overallScore)
        guard scores.count >= 5 else { return nil }

        let firstHalf = Array(scores.prefix(scores.count / 2))
        let secondHalf = Array(scores.suffix(scores.count / 2))
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let diff = secondAvg - firstAvg

        guard abs(diff) > 0.05 else { return nil }

        if diff > 0 {
            return Pattern(
                title: "You're improving",
                detail: String(format: "Your recent sessions are %.0f%% better than your earlier ones", diff * 100),
                icon: "arrow.up.right"
            )
        } else {
            return Pattern(
                title: "Scores are slipping",
                detail: String(format: "Your recent sessions are %.0f%% below your earlier ones. Time to recalibrate?", abs(diff) * 100),
                icon: "arrow.down.right"
            )
        }
    }

    private static func detectConsistentWeakness(_ sessions: [LocalSession]) -> Pattern? {
        var worstCounts: [String: Int] = [:]
        for session in sessions {
            let scores = [
                ("Posture", session.postureScore ?? 1),
                ("Expression", session.expressionScore ?? 1),
                ("Habits", session.habitScore ?? 1),
                ("Speech", session.speechScore ?? 1),
            ]
            if let worst = scores.min(by: { $0.1 < $1.1 }) {
                worstCounts[worst.0, default: 0] += 1
            }
        }

        guard let consistent = worstCounts.max(by: { $0.value < $1.value }),
              Double(consistent.value) / Double(sessions.count) > 0.5 else { return nil }

        return Pattern(
            title: "\(consistent.key) is your biggest challenge",
            detail: "\(consistent.key) was your weakest area in \(consistent.value) of your last \(sessions.count) sessions",
            icon: "target"
        )
    }

    private static func detectDurationCorrelation(_ sessions: [LocalSession]) -> Pattern? {
        let withDuration = sessions.compactMap { s -> (TimeInterval, Double)? in
            guard let end = s.endedAt, let score = s.overallScore else { return nil }
            return (end.timeIntervalSince(s.startedAt), score)
        }
        guard withDuration.count >= 5 else { return nil }

        let short = withDuration.filter { $0.0 < 20 * 60 }  // < 20 min
        let long = withDuration.filter { $0.0 >= 20 * 60 }   // >= 20 min

        guard short.count >= 2, long.count >= 2 else { return nil }

        let shortAvg = short.map(\.1).reduce(0, +) / Double(short.count)
        let longAvg = long.map(\.1).reduce(0, +) / Double(long.count)
        let diff = shortAvg - longAvg

        guard diff > 0.1 else { return nil }

        return Pattern(
            title: "Longer sessions are harder",
            detail: String(format: "Sessions under 20 min average %.0f%% vs %.0f%% for longer ones. Consider shorter, more frequent sessions.", shortAvg * 100, longAvg * 100),
            icon: "timer"
        )
    }
}
