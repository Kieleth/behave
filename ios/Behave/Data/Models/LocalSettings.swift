import Foundation
import SwiftData

/// User settings and calibration data, stored locally.
@Model
final class LocalSettings {
    var id: UUID

    // Calibration
    var calibrationNoseY: Double
    var calibrationShoulderMidY: Double
    var calibrationHeadToShoulderRatio: Double
    var calibrationShoulderAngle: Double
    var calibrationShoulderWidth: Double
    var calibrationFaceBBoxHeight: Double
    var calibrationFaceBBoxCenterY: Double
    var calibrationFaceCenterX: Double
    var calibrationRoll: Double
    var calibrationNoseOffset: Double
    var lateralLeanEnabled: Bool
    var isCalibrated: Bool

    // Thresholds
    var postureWarningSeconds: Double
    var postureAlertSeconds: Double
    var expressionWarningSeconds: Double
    var habitWarningSeconds: Double

    // Preferences
    var audioAlertsEnabled: Bool
    var hapticAlertsEnabled: Bool
    var speechMonitoringEnabled: Bool
    var monitoredBehaviors: String   // JSON array: ["posture","expression","habits","speech"]

    // Pomodoro
    var pomodoroWorkMinutes: Double
    var pomodoroShortBreakMinutes: Double
    var pomodoroLongBreakMinutes: Double
    var pomodoroLongBreakInterval: Int

    init() {
        self.id = UUID()
        self.calibrationNoseY = 0
        self.calibrationShoulderMidY = 0
        self.calibrationHeadToShoulderRatio = 0
        self.calibrationShoulderAngle = 0
        self.calibrationShoulderWidth = 0
        self.calibrationFaceBBoxHeight = 0
        self.calibrationFaceBBoxCenterY = 0
        self.calibrationFaceCenterX = 0
        self.calibrationRoll = 0
        self.calibrationNoseOffset = 0
        self.lateralLeanEnabled = true
        self.isCalibrated = false
        self.postureWarningSeconds = 5
        self.postureAlertSeconds = 15
        self.expressionWarningSeconds = 10
        self.habitWarningSeconds = 1
        self.audioAlertsEnabled = true
        self.hapticAlertsEnabled = true
        self.speechMonitoringEnabled = false
        self.monitoredBehaviors = "[\"posture\",\"expression\",\"habits\"]"
        self.pomodoroWorkMinutes = 25
        self.pomodoroShortBreakMinutes = 5
        self.pomodoroLongBreakMinutes = 15
        self.pomodoroLongBreakInterval = 4
    }
}
