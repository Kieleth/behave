import SwiftUI

/// Compact pomodoro timer display for the session view control bar.
struct PomodoroOverlay: View {
    @ObservedObject var pomodoro: PomodoroTimer

    var body: some View {
        if pomodoro.isRunning {
            HStack(spacing: 8) {
                // Phase indicator dot
                Circle()
                    .fill(phaseColor)
                    .frame(width: 8, height: 8)

                Text(pomodoro.phaseLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(pomodoro.formattedTime)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)

                // Completed count
                if pomodoro.completedPomodoros > 0 {
                    Text("\(pomodoro.completedPomodoros)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.6), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var phaseColor: Color {
        switch pomodoro.phase {
        case .idle: return .gray
        case .work: return .green
        case .shortBreak: return .blue
        case .longBreak: return .purple
        }
    }
}
