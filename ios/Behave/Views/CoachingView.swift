import SwiftUI
import SwiftData

/// Coaching view — shows rule-based session reports, patterns, and tips.
/// Replaces the original Claude chat stub with on-device coaching.
struct CoachingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalSession.startedAt, order: .reverse)
    private var sessions: [LocalSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        // Latest session report
                        if let report = CoachingEngine.reportForLastSession(context: modelContext) {
                            lastSessionCard(report)
                        }

                        // Patterns
                        let patterns = CoachingEngine.detectPatterns(context: modelContext)
                        if !patterns.isEmpty {
                            patternsSection(patterns)
                        }

                        // Tips
                        tipsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Coach")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "figure.stand")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No sessions yet")
                .font(.headline)
            Text("Complete your first session to get personalized coaching insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.vertical, 60)
    }

    // MARK: - Last session report

    private func lastSessionCard(_ report: CoachingEngine.SessionReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Last session")
                    .font(.headline)
                Spacer()
                Text(formatDuration(report.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Score breakdown
            HStack(spacing: 12) {
                scorePill("Posture", report.scores.posture)
                scorePill("Face", report.scores.expression)
                scorePill("Habits", report.scores.habit)
                scorePill("Speech", report.scores.speech)
            }

            // Overall
            HStack {
                Text("Overall")
                    .font(.subheadline.bold())
                Spacer()
                Text(String(format: "%.0f%%", report.scores.overall * 100))
                    .font(.title2.bold())
                    .foregroundStyle(scoreColor(report.scores.overall))
            }

            // Comparison
            if let comparison = report.comparison {
                HStack(spacing: 6) {
                    Image(systemName: trendIcon(comparison.trend))
                        .foregroundStyle(trendColor(comparison.trend))
                    Text(comparison.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Events summary
            if !report.events.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Events detected")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(report.events.prefix(5), id: \.type) { event in
                        HStack {
                            Text(formatEventType(event.type))
                                .font(.caption)
                            Spacer()
                            Text("\(event.count)x")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Tip
            if let tip = report.tip {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(.subheadline.bold())
                    Text(tip.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                    Text(tip.source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Patterns

    private func patternsSection(_ patterns: [CoachingEngine.Pattern]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patterns")
                .font(.headline)

            ForEach(Array(patterns.enumerated()), id: \.offset) { _, pattern in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: pattern.icon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pattern.title)
                            .font(.subheadline.bold())
                        Text(pattern.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Tips section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips")
                .font(.headline)

            let categories = ["posture", "expression", "habit", "speech"]
            ForEach(categories, id: \.self) { category in
                if let tip = TipLibrary.tip(for: category) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: categoryIcon(category))
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.title)
                                .font(.subheadline.bold())
                            Text(tip.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                            Text(tip.source)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Helpers

    private func scorePill(_ label: String, _ score: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f%%", score * 100))
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(scoreColor(score))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .yellow }
        return .red
    }

    private func trendIcon(_ trend: CoachingEngine.Comparison.Trend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    private func trendColor(_ trend: CoachingEngine.Comparison.Trend) -> Color {
        switch trend {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return "\(mins) min"
    }

    private func formatEventType(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "posture": return "figure.stand"
        case "expression": return "face.smiling"
        case "habit": return "hand.raised"
        case "speech": return "waveform"
        default: return "lightbulb"
        }
    }
}
