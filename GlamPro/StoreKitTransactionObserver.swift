import Foundation
import StoreKit

@MainActor
final class StoreKitTransactionObserver {
    static let shared = StoreKitTransactionObserver()

    private var updatesTask: Task<Void, Never>?
    private var handledTransactionIDs = Set<UInt64>()

    private init() {}

    func startIfNeeded(sessionManager: SessionManager) {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            guard let self else { return }

            for await verification in Transaction.updates {
                guard !Task.isCancelled else { break }
                await self.handle(verification, sessionManager: sessionManager)
            }
        }
        print("[StoreKit] transaction updates observer started")
    }

    private func handle(
        _ verification: VerificationResult<StoreKit.Transaction>,
        sessionManager: SessionManager
    ) async {
        let transaction: StoreKit.Transaction
        do {
            transaction = try verification.payloadValue
        } catch {
            print("[StoreKit] ignored unverified transaction update")
            return
        }

        if handledTransactionIDs.contains(transaction.id) {
            return
        }
        handledTransactionIDs.insert(transaction.id)

        if transaction.productType == .autoRenewable {
            await SubscriptionStore.shared.handleTransactionUpdate(verification, sessionManager: sessionManager)
            return
        }

        if transaction.productType == .consumable {
            await CreditPurchaseStore.shared.handleTransactionUpdate(verification, sessionManager: sessionManager)
            return
        }

        // Keep unknown product types from reappearing endlessly.
        await transaction.finish()
        print("[StoreKit] finished unsupported transaction type: \(transaction.productID)")
    }
}
