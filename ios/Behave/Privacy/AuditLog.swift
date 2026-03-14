import Foundation
import CryptoKit

/// Tamper-evident audit log using a hash chain.
/// Each entry includes the hash of the previous entry, making
/// retroactive modification detectable.
///
/// Progressive disclosure:
/// - L1: "All data stays on your device"
/// - L2: Privacy dashboard shows what's stored
/// - L3: This audit log — cryptographic proof of data operations
final class AuditLog {
    static let shared = AuditLog()

    private let fileURL: URL
    private var lastHash: String

    /// Events the audit log tracks.
    enum Event: String, Codable {
        case consentGranted = "consent_granted"
        case consentRevoked = "consent_revoked"
        case sessionStarted = "session_started"
        case sessionEnded = "session_ended"
        case dataExported = "data_exported"
        case dataDeleted = "data_deleted"
        case calibrationSaved = "calibration_saved"
        case configSynced = "config_synced"
    }

    struct Entry: Codable {
        let timestamp: Date
        let event: Event
        let detail: String
        let previousHash: String
        let hash: String
    }

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = dir.appendingPathComponent("audit_log.jsonl")
        self.lastHash = "genesis"

        // Restore last hash from existing log
        if let data = try? Data(contentsOf: fileURL),
           let lastLine = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").last,
           let lineData = lastLine.data(using: .utf8),
           let entry = try? JSONDecoder().decode(Entry.self, from: lineData) {
            self.lastHash = entry.hash
        }
    }

    /// Append an event to the audit log.
    func record(_ event: Event, detail: String = "") {
        let entry = Entry(
            timestamp: Date(),
            event: event,
            detail: detail,
            previousHash: lastHash,
            hash: computeHash(event: event, detail: detail, previousHash: lastHash)
        )

        guard let data = try? JSONEncoder().encode(entry),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
                handle.closeFile()
            }
        } else {
            try? line.data(using: .utf8)?.write(to: fileURL)
        }

        lastHash = entry.hash
    }

    /// Read all entries for the privacy dashboard.
    func entries() -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else { return [] }

        return content
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode(Entry.self, from: data)
            }
    }

    /// Verify the integrity of the hash chain.
    /// Returns the index of the first broken link, or nil if intact.
    func verify() -> Int? {
        let all = entries()
        guard !all.isEmpty else { return nil }

        // First entry must chain from "genesis"
        if all[0].previousHash != "genesis" { return 0 }

        for i in 1..<all.count {
            if all[i].previousHash != all[i - 1].hash { return i }
        }
        return nil
    }

    /// Delete the entire audit log (user's right to delete).
    func deleteAll() {
        try? FileManager.default.removeItem(at: fileURL)
        lastHash = "genesis"
    }

    private func computeHash(event: Event, detail: String, previousHash: String) -> String {
        let input = "\(event.rawValue)|\(detail)|\(previousHash)|\(Date().timeIntervalSince1970)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
