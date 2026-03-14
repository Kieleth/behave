import Foundation
import AVFoundation
import UIKit
import Combine

/// Central enforcement engine. Receives classifier results, applies thresholds,
/// triggers alerts. Inherits the `wrongs_count / oks_count` pattern from the original.
final class EnforcementEngine: ObservableObject {
    @Published var postureStatus: BehaviorStatus = .ok
    @Published var expressionStatus: BehaviorStatus = .ok
    @Published var habitStatus: BehaviorStatus = .ok
    @Published var speechStatus: BehaviorStatus = .ok
    @Published var activeAlerts: [BehaviorAlert] = []
    @Published var overallScore: Double = 1.0

    private var postureEnforcer = BehaviorEnforcer(name: "posture", warningAfter: 5.0, alertAfter: 15.0)
    private var expressionEnforcer = BehaviorEnforcer(name: "expression", warningAfter: 10.0, alertAfter: 30.0)
    private var habitEnforcer = BehaviorEnforcer(name: "habit", warningAfter: 1.0, alertAfter: 3.0)

    /// Callback fired on every alert — used by orchestrator to persist events.
    var onAlert: ((BehaviorAlert) -> Void)?

    /// Which feedback channels are active.
    var audioAlertsEnabled = true
    var hapticAlertsEnabled = true

    /// Which behaviors to monitor. Nil = monitor all.
    var monitoredBehaviors: Set<String>?

    private let synthesizer = AVSpeechSynthesizer()
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    /// Reconfigure thresholds from persisted settings.
    func configure(from settings: LocalSettings) {
        postureEnforcer = BehaviorEnforcer(
            name: "posture",
            warningAfter: settings.postureWarningSeconds,
            alertAfter: settings.postureAlertSeconds
        )
        expressionEnforcer = BehaviorEnforcer(
            name: "expression",
            warningAfter: settings.expressionWarningSeconds,
            alertAfter: settings.expressionWarningSeconds * 3  // alert = 3x warning
        )
        habitEnforcer = BehaviorEnforcer(
            name: "habit",
            warningAfter: settings.habitWarningSeconds,
            alertAfter: settings.habitWarningSeconds * 3
        )
        audioAlertsEnabled = settings.audioAlertsEnabled
        hapticAlertsEnabled = settings.hapticAlertsEnabled

        // Parse monitored behaviors from JSON
        if let data = settings.monitoredBehaviors.data(using: .utf8),
           let behaviors = try? JSONDecoder().decode([String].self, from: data) {
            monitoredBehaviors = Set(behaviors)
        }
    }

    /// Process all classifier results each frame.
    /// Skips behaviors not in `monitoredBehaviors` if set.
    func process(
        posture: PostureClassifier.Result?,
        expression: ExpressionClassifier.Result?,
        habits: HabitClassifier.Result?,
        speech: SpeechClassifier.Result?
    ) {
        let now = Date()
        let monitored = monitoredBehaviors

        // Posture
        if monitored == nil || monitored!.contains("posture"), let p = posture {
            let result = postureEnforcer.update(isGood: p.isGood, at: now)
            postureStatus = result.status
            if let alert = result.alert { fire(alert) }
        }

        // Expression
        if monitored == nil || monitored!.contains("expression"), let e = expression {
            let isGood = e.tension < 0.5
            let result = expressionEnforcer.update(isGood: isGood, at: now)
            expressionStatus = result.status
            if let alert = result.alert { fire(alert) }
        }

        // Habits
        if monitored == nil || monitored!.contains("habits"), let h = habits {
            let isGood = h.detectedHabits.isEmpty
            let result = habitEnforcer.update(isGood: isGood, at: now)
            habitStatus = result.status
            if let alert = result.alert { fire(alert) }
        }

        // Speech
        if monitored == nil || monitored!.contains("speech"), let s = speech {
            speechStatus = s.fillerWordCount > 3 ? .warning : .ok
        }

        // Overall score (0-1)
        let scores = [postureStatus, expressionStatus, habitStatus, speechStatus].map { $0.score }
        overallScore = scores.reduce(0, +) / Double(scores.count)
    }

    private func fire(_ alert: BehaviorAlert) {
        activeAlerts.append(alert)
        // Keep only recent alerts
        if activeAlerts.count > 20 {
            activeAlerts.removeFirst()
        }

        // Haptic feedback
        if hapticAlertsEnabled {
            haptic.impactOccurred()
        }

        // Spoken alert for critical issues
        if audioAlertsEnabled && alert.severity == .alert {
            speak(alert.message)
        }

        // Notify orchestrator to persist the event
        onAlert?(alert)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 0.7
        synthesizer.speak(utterance)
    }

    func reset() {
        postureEnforcer.reset()
        expressionEnforcer.reset()
        habitEnforcer.reset()
        postureStatus = .ok
        expressionStatus = .ok
        habitStatus = .ok
        speechStatus = .ok
        activeAlerts = []
        overallScore = 1.0
    }
}

// MARK: - Supporting Types

enum BehaviorStatus {
    case ok, warning, alert

    var score: Double {
        switch self {
        case .ok: return 1.0
        case .warning: return 0.6
        case .alert: return 0.2
        }
    }

    var color: String {
        switch self {
        case .ok: return "green"
        case .warning: return "yellow"
        case .alert: return "red"
        }
    }
}

struct BehaviorAlert: Identifiable {
    let id = UUID()
    let behavior: String
    let message: String
    let severity: BehaviorStatus
    let timestamp: Date
}

/// Tracks violation duration for a single behavior.
/// Mirrors the original `wrongs_count / oks_count / wrongs_max` logic,
/// but uses time instead of frame count.
struct BehaviorEnforcer {
    let name: String
    let warningAfter: TimeInterval   // seconds of bad behavior before warning
    let alertAfter: TimeInterval     // seconds before escalating to alert

    private var violationStart: Date?
    private var lastAlertTime: Date?
    private var cooldownInterval: TimeInterval = 30.0

    struct EnforcerResult {
        let status: BehaviorStatus
        let alert: BehaviorAlert?
    }

    mutating func update(isGood: Bool, at now: Date) -> EnforcerResult {
        if isGood {
            violationStart = nil
            return EnforcerResult(status: .ok, alert: nil)
        }

        // Start tracking violation
        if violationStart == nil {
            violationStart = now
        }

        let elapsed = now.timeIntervalSince(violationStart!)

        // Check cooldown
        let inCooldown = lastAlertTime.map { now.timeIntervalSince($0) < cooldownInterval } ?? false

        if elapsed >= alertAfter && !inCooldown {
            lastAlertTime = now
            violationStart = now // reset to avoid spamming
            let alert = BehaviorAlert(
                behavior: name,
                message: alertMessage(for: name),
                severity: .alert,
                timestamp: now
            )
            return EnforcerResult(status: .alert, alert: alert)
        } else if elapsed >= warningAfter {
            return EnforcerResult(status: .warning, alert: nil)
        }

        return EnforcerResult(status: .ok, alert: nil)
    }

    mutating func reset() {
        violationStart = nil
        lastAlertTime = nil
    }

    private func alertMessage(for behavior: String) -> String {
        switch behavior {
        case "posture": return "Your posture needs attention. Try sitting up straight."
        case "expression": return "You seem tense. Try relaxing your face."
        case "habit": return "Hands away from your face."
        default: return "Check your \(behavior)."
        }
    }
}
