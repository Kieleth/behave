import SwiftUI
import SwiftData

/// Settings: calibration, thresholds, preferences, account.
struct SettingsView: View {
    @Query private var allSettings: [LocalSettings]
    @Environment(\.modelContext) private var modelContext
    @State private var showPaywall = false

    private var settings: LocalSettings {
        if let existing = allSettings.first { return existing }
        let new = LocalSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monitoring") {
                    Toggle("Posture", isOn: binding(for: "posture"))
                    Toggle("Facial Expressions", isOn: binding(for: "expression"))
                    Toggle("Habits (nail biting, etc.)", isOn: binding(for: "habits"))
                    Toggle("Speech Analysis", isOn: .init(
                        get: { settings.speechMonitoringEnabled },
                        set: { settings.speechMonitoringEnabled = $0 }
                    ))
                }

                Section("Alerts") {
                    Toggle("Audio Alerts", isOn: .init(
                        get: { settings.audioAlertsEnabled },
                        set: { settings.audioAlertsEnabled = $0 }
                    ))
                    Toggle("Haptic Feedback", isOn: .init(
                        get: { settings.hapticAlertsEnabled },
                        set: { settings.hapticAlertsEnabled = $0 }
                    ))
                }

                Section("Sensitivity") {
                    HStack {
                        Text("Posture warning after")
                        Spacer()
                        Text("\(Int(settings.postureWarningSeconds))s")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: .init(
                            get: { settings.postureWarningSeconds },
                            set: { settings.postureWarningSeconds = $0 }
                        ),
                        in: 2...30,
                        step: 1
                    )
                }

                Section("Pomodoro") {
                    HStack {
                        Text("Work interval")
                        Spacer()
                        Text("\(Int(settings.pomodoroWorkMinutes)) min")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: .init(
                            get: { settings.pomodoroWorkMinutes },
                            set: { settings.pomodoroWorkMinutes = $0 }
                        ),
                        in: 15...60,
                        step: 5
                    )

                    HStack {
                        Text("Short break")
                        Spacer()
                        Text("\(Int(settings.pomodoroShortBreakMinutes)) min")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: .init(
                            get: { settings.pomodoroShortBreakMinutes },
                            set: { settings.pomodoroShortBreakMinutes = $0 }
                        ),
                        in: 3...15,
                        step: 1
                    )

                    HStack {
                        Text("Long break")
                        Spacer()
                        Text("\(Int(settings.pomodoroLongBreakMinutes)) min")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: .init(
                            get: { settings.pomodoroLongBreakMinutes },
                            set: { settings.pomodoroLongBreakMinutes = $0 }
                        ),
                        in: 10...30,
                        step: 5
                    )
                }

                Section("Calibration") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(settings.isCalibrated ? "Calibrated" : "Not calibrated")
                            .foregroundStyle(settings.isCalibrated ? .green : .secondary)
                    }
                }

                Section("Privacy") {
                    NavigationLink {
                        PrivacyDashboardView()
                    } label: {
                        Label("Privacy dashboard", systemImage: "lock.shield")
                    }

                    if SubscriptionManager.shared.isPro {
                        Label("Behave Pro", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Upgrade to Pro", systemImage: "star")
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    /// Binding for monitored behaviors JSON array
    private func binding(for behavior: String) -> Binding<Bool> {
        Binding(
            get: {
                let data = settings.monitoredBehaviors.data(using: .utf8) ?? Data()
                let behaviors = (try? JSONDecoder().decode([String].self, from: data)) ?? []
                return behaviors.contains(behavior)
            },
            set: { enabled in
                let data = settings.monitoredBehaviors.data(using: .utf8) ?? Data()
                var behaviors = (try? JSONDecoder().decode([String].self, from: data)) ?? []
                if enabled {
                    if !behaviors.contains(behavior) { behaviors.append(behavior) }
                } else {
                    behaviors.removeAll { $0 == behavior }
                }
                if let encoded = try? JSONEncoder().encode(behaviors),
                   let str = String(data: encoded, encoding: .utf8) {
                    settings.monitoredBehaviors = str
                }
            }
        )
    }
}
