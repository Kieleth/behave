import Foundation
import Combine

/// Syncs user configuration across devices via iCloud Key-Value Store.
/// Only config/preferences sync — no behavioral data, no session history.
final class ConfigSync: ObservableObject {
    static let shared = ConfigSync()

    private let store = NSUbiquitousKeyValueStore.default
    private var cancellable: AnyCancellable?

    /// Keys that sync across devices.
    private enum Key {
        static let monitoredBehaviors = "config.monitoredBehaviors"
        static let postureWarningSeconds = "config.postureWarningSeconds"
        static let postureAlertSeconds = "config.postureAlertSeconds"
        static let expressionWarningSeconds = "config.expressionWarningSeconds"
        static let habitWarningSeconds = "config.habitWarningSeconds"
        static let audioAlertsEnabled = "config.audioAlertsEnabled"
        static let hapticAlertsEnabled = "config.hapticAlertsEnabled"
        static let speechMonitoringEnabled = "config.speechMonitoringEnabled"
        static let pomodoroWorkDuration = "config.pomodoroWorkDuration"
        static let pomodoroShortBreak = "config.pomodoroShortBreak"
        static let pomodoroLongBreak = "config.pomodoroLongBreak"
        static let pomodoroLongBreakInterval = "config.pomodoroLongBreakInterval"
    }

    private init() {
        // Listen for external changes (from other devices)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    /// Push local settings to iCloud.
    func push(from settings: LocalSettings) {
        store.set(settings.monitoredBehaviors, forKey: Key.monitoredBehaviors)
        store.set(settings.postureWarningSeconds, forKey: Key.postureWarningSeconds)
        store.set(settings.postureAlertSeconds, forKey: Key.postureAlertSeconds)
        store.set(settings.expressionWarningSeconds, forKey: Key.expressionWarningSeconds)
        store.set(settings.habitWarningSeconds, forKey: Key.habitWarningSeconds)
        store.set(settings.audioAlertsEnabled, forKey: Key.audioAlertsEnabled)
        store.set(settings.hapticAlertsEnabled, forKey: Key.hapticAlertsEnabled)
        store.set(settings.speechMonitoringEnabled, forKey: Key.speechMonitoringEnabled)
        store.set(settings.pomodoroWorkMinutes, forKey: Key.pomodoroWorkDuration)
        store.set(settings.pomodoroShortBreakMinutes, forKey: Key.pomodoroShortBreak)
        store.set(settings.pomodoroLongBreakMinutes, forKey: Key.pomodoroLongBreak)
        store.set(settings.pomodoroLongBreakInterval, forKey: Key.pomodoroLongBreakInterval)
        store.synchronize()

        AuditLog.shared.record(.configSynced, detail: "pushed to iCloud")
    }

    /// Pull remote settings into a LocalSettings instance.
    /// Returns true if any values were updated.
    @discardableResult
    func pull(into settings: LocalSettings) -> Bool {
        var changed = false

        if let val = store.string(forKey: Key.monitoredBehaviors), val != settings.monitoredBehaviors {
            settings.monitoredBehaviors = val
            changed = true
        }

        let pairs: [(String, WritableKeyPath<LocalSettings, Double>, Double)] = [
            (Key.postureWarningSeconds, \.postureWarningSeconds, settings.postureWarningSeconds),
            (Key.postureAlertSeconds, \.postureAlertSeconds, settings.postureAlertSeconds),
            (Key.expressionWarningSeconds, \.expressionWarningSeconds, settings.expressionWarningSeconds),
            (Key.habitWarningSeconds, \.habitWarningSeconds, settings.habitWarningSeconds),
        ]

        for (key, keyPath, current) in pairs {
            let remote = store.double(forKey: key)
            if remote > 0 && remote != current {
                settings[keyPath: keyPath] = remote
                changed = true
            }
        }

        let boolPairs: [(String, WritableKeyPath<LocalSettings, Bool>, Bool)] = [
            (Key.audioAlertsEnabled, \.audioAlertsEnabled, settings.audioAlertsEnabled),
            (Key.hapticAlertsEnabled, \.hapticAlertsEnabled, settings.hapticAlertsEnabled),
            (Key.speechMonitoringEnabled, \.speechMonitoringEnabled, settings.speechMonitoringEnabled),
        ]

        for (key, keyPath, current) in boolPairs {
            let remote = store.bool(forKey: key)
            if store.object(forKey: key) != nil && remote != current {
                settings[keyPath: keyPath] = remote
                changed = true
            }
        }

        // Pomodoro settings
        let pomWork = store.double(forKey: Key.pomodoroWorkDuration)
        if pomWork > 0 && pomWork != settings.pomodoroWorkMinutes {
            settings.pomodoroWorkMinutes = pomWork
            changed = true
        }
        let pomShort = store.double(forKey: Key.pomodoroShortBreak)
        if pomShort > 0 && pomShort != settings.pomodoroShortBreakMinutes {
            settings.pomodoroShortBreakMinutes = pomShort
            changed = true
        }
        let pomLong = store.double(forKey: Key.pomodoroLongBreak)
        if pomLong > 0 && pomLong != settings.pomodoroLongBreakMinutes {
            settings.pomodoroLongBreakMinutes = pomLong
            changed = true
        }
        let pomInterval = store.longLong(forKey: Key.pomodoroLongBreakInterval)
        if pomInterval > 0 && Int(pomInterval) != settings.pomodoroLongBreakInterval {
            settings.pomodoroLongBreakInterval = Int(pomInterval)
            changed = true
        }

        if changed {
            AuditLog.shared.record(.configSynced, detail: "pulled from iCloud")
        }
        return changed
    }

    @objc private func storeDidChange(_ notification: Notification) {
        objectWillChange.send()
    }
}
