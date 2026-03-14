import Foundation
import UserNotifications
import Combine

/// Pomodoro timer managing work/break intervals.
/// Integrates with SessionOrchestrator to pause monitoring during breaks.
@MainActor
final class PomodoroTimer: ObservableObject {
    enum Phase: Equatable {
        case idle
        case work
        case shortBreak
        case longBreak
    }

    @Published var phase: Phase = .idle
    @Published var remainingSeconds: TimeInterval = 0
    @Published var completedPomodoros: Int = 0

    // Configurable intervals (defaults, overridden by LocalSettings)
    var workDuration: TimeInterval = 25 * 60       // 25 min
    var shortBreakDuration: TimeInterval = 5 * 60  // 5 min
    var longBreakDuration: TimeInterval = 15 * 60  // 15 min
    var longBreakInterval: Int = 4                  // long break every N pomodoros

    /// Fires when transitioning between phases.
    var onPhaseChange: ((Phase) -> Void)?

    private var timer: Timer?

    var isRunning: Bool { phase != .idle }

    var isBreak: Bool {
        phase == .shortBreak || phase == .longBreak
    }

    var phaseLabel: String {
        switch phase {
        case .idle: return "Ready"
        case .work: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var progress: Double {
        let total: TimeInterval
        switch phase {
        case .idle: return 0
        case .work: total = workDuration
        case .shortBreak: total = shortBreakDuration
        case .longBreak: total = longBreakDuration
        }
        guard total > 0 else { return 0 }
        return 1.0 - (remainingSeconds / total)
    }

    /// Start a work phase (or resume from idle).
    func startWork() {
        phase = .work
        remainingSeconds = workDuration
        startTimer()
        onPhaseChange?(.work)
    }

    /// Manually skip to break.
    func startBreak() {
        completedPomodoros += 1
        let isLong = completedPomodoros % longBreakInterval == 0
        phase = isLong ? .longBreak : .shortBreak
        remainingSeconds = isLong ? longBreakDuration : shortBreakDuration
        startTimer()
        scheduleNotification(phase: phase)
        onPhaseChange?(phase)
    }

    /// Stop everything and reset.
    func stop() {
        timer?.invalidate()
        timer = nil
        phase = .idle
        remainingSeconds = 0
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        onPhaseChange?(.idle)
    }

    /// Skip the current phase (break or work) and move to the next.
    func skip() {
        timer?.invalidate()
        timer = nil
        if isBreak {
            startWork()
        } else {
            startBreak()
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            timer?.invalidate()
            timer = nil
            if phase == .work {
                startBreak()
            } else {
                startWork()
            }
        }
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(phase: Phase) {
        let content = UNMutableNotificationContent()
        switch phase {
        case .shortBreak, .longBreak:
            content.title = "Break time"
            content.body = "Time to stretch and move. Your break has started."
            content.sound = .default
        case .work:
            content.title = "Back to focus"
            content.body = "Break's over. Let's get back to work."
            content.sound = .default
        case .idle:
            return
        }

        // Notify at the start of the phase
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoro.\(phase)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Formatting

    var formattedTime: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
