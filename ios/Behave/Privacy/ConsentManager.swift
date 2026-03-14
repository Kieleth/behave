import Foundation
import SwiftUI

/// Manages BIPA-compliant consent for biometric data processing.
/// Gates camera access until the user gives explicit, informed consent.
/// Consent state is persisted in UserDefaults (not SwiftData — must survive data deletion).
@MainActor
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    @Published var hasConsented: Bool
    @Published var consentDate: Date?

    private let defaults = UserDefaults.standard
    private let consentKey = "behave.consent.biometric"
    private let consentDateKey = "behave.consent.date"
    private let consentVersionKey = "behave.consent.version"

    /// Bump this when the consent language changes materially.
    /// Users will be re-prompted on version mismatch.
    static let currentConsentVersion = 1

    private init() {
        let storedVersion = defaults.integer(forKey: consentVersionKey)
        let consented = defaults.bool(forKey: consentKey) && storedVersion == Self.currentConsentVersion
        self.hasConsented = consented
        self.consentDate = defaults.object(forKey: consentDateKey) as? Date
    }

    /// Record that the user gave informed consent.
    func grantConsent() {
        let now = Date()
        defaults.set(true, forKey: consentKey)
        defaults.set(now, forKey: consentDateKey)
        defaults.set(Self.currentConsentVersion, forKey: consentVersionKey)
        hasConsented = true
        consentDate = now

        AuditLog.shared.record(.consentGranted)
    }

    /// Revoke consent. Stops all monitoring.
    func revokeConsent() {
        defaults.set(false, forKey: consentKey)
        defaults.removeObject(forKey: consentDateKey)
        defaults.set(0, forKey: consentVersionKey)
        hasConsented = false
        consentDate = nil

        AuditLog.shared.record(.consentRevoked)
    }

    // MARK: - BIPA disclosure text

    /// The legally required disclosure shown before consent.
    static let disclosureText = """
    Behave uses your device's camera to analyze body posture, facial expressions, \
    and hand movements. It uses your microphone to analyze speech patterns.

    HOW YOUR DATA IS PROCESSED:
    • All analysis runs entirely on your device using Apple's Vision framework
    • No images, video, or audio are ever stored or transmitted
    • Raw camera data is immediately converted to geometric measurements \
    (angles, distances) and discarded
    • Only behavioral scores and event summaries are saved — on your device only

    WHAT IS NOT COLLECTED:
    • No biometric templates or identifiers are created or stored
    • No data is sent to any server
    • No accounts or personal information are required

    YOUR RIGHTS:
    • You can revoke consent at any time in Settings
    • You can delete all stored data at any time
    • You can export your data at any time

    By tapping "I Understand & Agree", you acknowledge this disclosure and \
    consent to on-device processing of camera and microphone data for \
    behavioral analysis as described above.
    """
}
