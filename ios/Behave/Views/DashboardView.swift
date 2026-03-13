import SwiftUI
import SwiftData
import Charts

/// Dashboard showing session history and behavior trends.
struct DashboardView: View {
    @Query(sort: \LocalSession.startedAt, order: .reverse)
    private var sessions: [LocalSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Today's summary
                    todaySummary

                    // Score trend chart
                    if sessions.count >= 2 {
                        scoreTrendChart
                    }

                    // Recent sessions
                    recentSessions
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }

    private var todaySummary: some View {
        let today = sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
        let avgScore = today.compactMap(\.overallScore).reduce(0, +) / max(1, Double(today.count))

        return VStack(spacing: 12) {
            Text("Today")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                ScoreCard(title: "Sessions", value: "\(today.count)", color: .blue)
                ScoreCard(title: "Avg Score", value: String(format: "%.0f%%", avgScore * 100), color: scoreColor(avgScore))
            }
        }
    }

    private var scoreTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score Trend")
                .font(.headline)

            Chart(sessions.prefix(20).reversed(), id: \.id) { session in
                LineMark(
                    x: .value("Date", session.startedAt),
                    y: .value("Score", (session.overallScore ?? 0) * 100)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 150)
            .chartYScale(domain: 0...100)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if sessions.isEmpty {
                Text("No sessions yet. Start your first session to see data here.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(sessions.prefix(10)) { session in
                    SessionRow(session: session)
                }
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .yellow }
        return .red
    }
}

struct ScoreCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionRow: View {
    let session: LocalSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startedAt, style: .date)
                    .font(.subheadline.bold())
                Text(session.startedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let score = session.overallScore {
                Text(String(format: "%.0f%%", score * 100))
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(score >= 0.8 ? .green : score >= 0.5 ? .yellow : .red)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
