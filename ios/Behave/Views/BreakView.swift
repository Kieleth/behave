import SwiftUI

/// Break card shown during pomodoro break intervals.
/// Displays a contextual stretch/move suggestion based on the worst
/// behavior from the preceding work interval.
struct BreakView: View {
    let suggestion: BreakSuggestionEngine.Suggestion
    @ObservedObject var pomodoro: PomodoroTimer
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Break type header
            HStack {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.blue)
                Text(pomodoro.phaseLabel)
                    .font(.headline)
                Spacer()
                Text(pomodoro.formattedTime)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            ProgressView(value: pomodoro.progress)
                .tint(.blue)

            // Suggestion card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: suggestion.icon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.headline)
                        Text(suggestion.duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(suggestion.description)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Completed pomodoros
            HStack(spacing: 6) {
                ForEach(0..<pomodoro.completedPomodoros, id: \.self) { _ in
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                if pomodoro.completedPomodoros > 0 {
                    Text("\(pomodoro.completedPomodoros) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Skip break button
            Button {
                onSkip()
            } label: {
                Text("Skip break")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}
