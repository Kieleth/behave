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

    init() {
        self.id = UUID()
        self.calibrationNoseY = 0
        self.calibrationShoulderMidY = 0
        self.calibrationHeadToShoulderRatio = 0
        self.calibrationShoulderAngle = 0
        self.isCalibrated = false
        self.postureWarningSeconds = 5
        self.postureAlertSeconds = 15
        self.expressionWarningSeconds = 10
        self.habitWarningSeconds = 1
        self.audioAlertsEnabled = true
        self.hapticAlertsEnabled = true
        self.speechMonitoringEnabled = false
        self.monitoredBehaviors = "[\"posture\",\"expression\",\"habits\"]"
    }
}
