import SwiftUI
import SwiftData

/// Progressive disclosure privacy dashboard.
/// L1: Simple statement + data summary
/// L2: Detailed breakdown of what's stored
/// L3: Audit log with hash-chain verification
struct PrivacyDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [LocalSession]
    @Query private var events: [LocalEvent]
    @ObservedObject var consentManager = ConsentManager.shared

    @State private var showAuditLog = false
    @State private var chainIntact: Bool?

    var body: some View {
        NavigationStack {
            List {
                // L1: High-level statement
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your data never leaves this device")
                                .font(.headline)
                            Text("All behavioral analysis runs on-device. No servers, no accounts, no tracking.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                    }
                }

                // L2: What's stored
                Section("What's on this device") {
                    dataRow("Sessions recorded", "\(sessions.count)")
                    dataRow("Behavioral events", "\(events.count)")
                    dataRow("Consent given", consentManager.consentDate.map {
                        $0.formatted(date: .abbreviated, time: .shortened)
                    } ?? "Not yet")

                    let totalBytes = estimateStorageBytes()
                    dataRow("Storage used", ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file))
                }

                // L2: What's NOT stored
                Section("What's NOT stored") {
                    notStoredRow("Images or video", "Camera frames are processed and immediately discarded")
                    notStoredRow("Audio recordings", "Speech is analyzed in real-time, never saved")
                    notStoredRow("Biometric templates", "No facial geometry or body maps are retained")
                    notStoredRow("Personal information", "No name, email, or Apple ID stored")
                }

                // L2: Actions
                Section("Your data, your control") {
                    Button("Export all data") {
                        exportData()
                    }

                    Button("Delete all data", role: .destructive) {
                        deleteAllData()
                    }

                    Button("Revoke consent", role: .destructive) {
                        consentManager.revokeConsent()
                    }
                }

                // L3: Audit log (for the curious)
                Section {
                    DisclosureGroup("Audit log") {
                        let entries = AuditLog.shared.entries()
                        if entries.isEmpty {
                            Text("No entries yet")
                                .foregroundStyle(.secondary)
                        } else {
                            // Chain verification
                            HStack {
                                Text("Hash chain integrity")
                                Spacer()
                                if let intact = chainIntact {
                                    Label(
                                        intact ? "Verified" : "Broken",
                                        systemImage: intact ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                                    )
                                    .foregroundStyle(intact ? .green : .red)
                                    .font(.caption)
                                } else {
                                    Button("Verify") {
                                        chainIntact = AuditLog.shared.verify() == nil
                                    }
                                    .font(.caption)
                                }
                            }

                            ForEach(entries.suffix(20).reversed(), id: \.hash) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(entry.event.rawValue)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(entry.timestamp, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(entry.hash.prefix(16) + "...")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("The audit log is a tamper-evident record of all data operations. Each entry is cryptographically chained to the previous one.")
                }
            }
            .navigationTitle("Privacy")
        }
    }

    private func dataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func notStoredRow(_ item: String, _ reason: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(item).font(.subheadline)
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "xmark.circle")
                .foregroundStyle(.red)
        }
    }

    private func estimateStorageBytes() -> Int {
        // Rough estimate: ~200 bytes per session, ~100 per event
        sessions.count * 200 + events.count * 100
    }

    private func exportData() {
        AuditLog.shared.record(.dataExported)
        // TODO: Generate JSON export and present share sheet
    }

    private func deleteAllData() {
        for session in sessions { modelContext.delete(session) }
        for event in events { modelContext.delete(event) }
        try? modelContext.save()
        AuditLog.shared.record(.dataDeleted)
    }
}
