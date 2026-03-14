import Foundation
import StoreKit

/// Manages subscriptions via StoreKit 2. All validation happens on-device.
/// No server needed — Apple handles receipt validation.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isPro = false
    @Published var products: [Product] = []

    /// Product identifiers — must match App Store Connect configuration.
    static let monthlyID = "com.behave.pro.monthly"
    static let yearlyID = "com.behave.pro.yearly"

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await checkEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load products

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
                .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkEntitlements()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restore() async {
        try? await AppStore.sync()
        await checkEntitlements()
    }

    // MARK: - Entitlements

    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID {
                isPro = true
                return
            }
        }
        isPro = false
    }

    // MARK: - Feature gating

    /// Check if a feature is available based on subscription status.
    enum Feature {
        case allBehaviors       // expression, habit, speech (posture is free)
        case unlimitedSessions  // free = 3/day
        case fullCoaching       // patterns, trends
        case customPomodoro     // configurable intervals
        case iCloudSync         // cross-device config
    }

    func isAvailable(_ feature: Feature) -> Bool {
        if isPro { return true }
        // Free tier: only posture + basic
        switch feature {
        case .allBehaviors, .fullCoaching, .customPomodoro, .iCloudSync:
            return false
        case .unlimitedSessions:
            return false  // enforced elsewhere via session count check
        }
    }

    /// Check if user has sessions remaining today (free tier: 3/day).
    func canStartSession(existingSessions: [LocalSession]) -> Bool {
        if isPro { return true }
        let today = existingSessions.filter { Calendar.current.isDateInToday($0.startedAt) }
        return today.count < 3
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let _ = try? self.checkVerified(result) {
                    await self.checkEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.unverified
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case unverified
    }
}
