import SwiftUI
import StoreKit

/// Subscription offer screen comparing free vs paid tiers.
struct PaywallView: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.yellow)
                        Text("Behave Pro")
                            .font(.title.bold())
                        Text("Unlock your full behavioral toolkit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Feature comparison
                    VStack(spacing: 0) {
                        featureRow("Posture monitoring", free: true, pro: true)
                        Divider()
                        featureRow("Pomodoro timer", free: true, pro: true)
                        Divider()
                        featureRow("Basic session summaries", free: true, pro: true)
                        Divider()
                        featureRow("3 sessions per day", free: true, pro: false, proLabel: "Unlimited")
                        Divider()
                        featureRow("Expression analysis", free: false, pro: true)
                        Divider()
                        featureRow("Habit tracking", free: false, pro: true)
                        Divider()
                        featureRow("Speech analysis", free: false, pro: true)
                        Divider()
                        featureRow("Pattern detection", free: false, pro: true)
                        Divider()
                        featureRow("Custom pomodoro intervals", free: false, pro: true)
                        Divider()
                        featureRow("Cross-device config sync", free: false, pro: true)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Product buttons
                    VStack(spacing: 12) {
                        ForEach(subscriptionManager.products, id: \.id) { product in
                            Button {
                                Task {
                                    purchasing = true
                                    _ = try? await subscriptionManager.purchase(product)
                                    purchasing = false
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(product.displayName)
                                        .font(.headline)
                                    Text(product.displayPrice)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(product.id == SubscriptionManager.yearlyID ? .blue : Color(.systemGray5))
                                .foregroundStyle(product.id == SubscriptionManager.yearlyID ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(purchasing)
                        }

                        Button("Restore purchases") {
                            Task { await subscriptionManager.restore() }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    // Privacy note
                    Label {
                        Text("Subscriptions are managed by Apple. No personal data is shared.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                            .font(.caption2)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func featureRow(_ feature: String, free: Bool, pro: Bool, proLabel: String? = nil) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Free column
            Group {
                if free {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "minus")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 50)

            // Pro column
            Group {
                if let label = proLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else if pro {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "minus")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70)
        }
        .padding(.vertical, 8)
    }
}
