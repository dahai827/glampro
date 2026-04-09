import SwiftUI
import StoreKit

struct CreditView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appBootstrap: AppBootstrapStore
    @ObservedObject private var store = CreditPurchaseStore.shared

    let onClose: () -> Void
    let onGrabDeal: () -> Void

    @State private var selectedPackID: String?
    @State private var purchaseState: CreditPurchaseActionState = .idle
    @State private var feedbackMessage: String?

    private var selectedPack: CreditPack? {
        if let selectedPackID,
           let pack = store.packages.first(where: { $0.id == selectedPackID }) {
            return pack
        }
        return store.packages.first
    }

    private var continueButtonTitle: String {
        switch purchaseState {
        case .idle:
            return "Continue"
        case .processing:
            return "Processing"
        case .verifying:
            return "Verifying"
        }
    }

    private var canContinue: Bool {
        purchaseState == .idle && selectedPack != nil && !store.packages.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            let safeBottom = geometry.safeAreaInsets.bottom

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                bottomPanel(bottomInset: safeBottom)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background {
                backgroundView
            }
            .overlay(alignment: .top) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .zIndex(2)
            }
        }
        .task {
            await store.preloadPackagesIfNeeded()
            syncSelectionIfNeeded()
        }
        .onAppear {
            syncSelectionIfNeeded()
        }
        .onChange(of: store.packages.map(\.id)) { _ in
            syncSelectionIfNeeded()
        }
        .alert(
            "Coins",
            isPresented: Binding(
                get: { feedbackMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        feedbackMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    private var backgroundView: some View {
        ZStack {
            if appBootstrap.isReviewVersion {
                LinearGradient(
                    colors: [Color(hex: "0E1118"), Color(hex: "172335"), Color(hex: "0A0C12")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color(hex: "120F19"), Color(hex: "1B2A44"), Color(hex: "090B10")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Circle()
                .fill(CalmTheme.purple.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: -110, y: -220)

            Circle()
                .fill(CalmTheme.orange.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 32)
                .offset(x: 120, y: -140)

            LinearGradient(
                colors: [Color.black.opacity(0.1), Color.black.opacity(0.32), Color.black.opacity(0.66)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            CircleIconButton(icon: "xmark", size: 40, action: onClose)
                .contentShape(Rectangle())

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: "c.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                Text("\(sessionManager.creditsBalance)")
                    .font(.calm(15, weight: .bold))
            }
            .foregroundColor(Color(hex: "F5C94F"))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(Color.black.opacity(0.18)))
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func bottomPanel(bottomInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Buy Coins")
                    .font(.calm(32, weight: .heavy))
                    .foregroundColor(.white)

                Text("Top up your balance and keep creating without interruption.")
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Group {
                if store.isLoading && store.packages.isEmpty {
                    loadingState
                } else if let loadError = store.loadError, store.packages.isEmpty {
                    errorState(message: loadError)
                } else if store.packages.isEmpty {
                    emptyState
                } else {
                    packsContent
                }
            }

            footerLinks
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, max(bottomInset, 10) + 20)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black.opacity(0.38))
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            Text("Loading coin packages...")
                .font(.calm(16, weight: .bold))
                .foregroundColor(.white)
            Text("Please wait a moment.")
                .font(.calm(13, weight: .medium))
                .foregroundColor(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(CalmTheme.orange)

            Text("Unable to load coin packages")
                .font(.calm(18, weight: .heavy))
                .foregroundColor(.white)

            Text(message)
                .font(.calm(14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await store.preloadPackagesIfNeeded(force: true)
                }
            } label: {
                Text("Retry")
                    .font(.calm(17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(CalmTheme.accentGradient)
                    )
            }
            .buttonStyle(.plain)

            if !sessionManager.isPro {
                Button(action: onGrabDeal) {
                    Text("Unlock Pro Instead")
                        .font(.calm(15, weight: .bold))
                        .foregroundColor(.white.opacity(0.84))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(CalmTheme.orange)

            Text("Coin packages unavailable")
                .font(.calm(18, weight: .heavy))
                .foregroundColor(.white)

            Text("No Apple coin packages are configured for this app yet.")
                .font(.calm(14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var packsContent: some View {
        VStack(spacing: 12) {
            ForEach(store.packages) { pack in
                packCard(pack)
            }

            Button(action: purchaseSelectedPack) {
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        if purchaseState != .idle {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(continueButtonTitle)
                            .font(.calm(18, weight: .bold))
                    }
                    .foregroundColor(.white)

                    if let selectedPack {
                        Text(selectedPack.displayPrice)
                            .font(.calm(13, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(canContinue ? CalmTheme.accentGradient : LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.10)], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Text("Consumable purchase. Coins are added to your current balance after verification.")
                .font(.calm(12, weight: .medium))
                .foregroundColor(.white.opacity(0.58))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Text("Terms")
                Text("·")
                Text("Privacy")
            }
            .font(.calm(12, weight: .medium))
            .foregroundColor(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func packCard(_ pack: CreditPack) -> some View {
        let isSelected = selectedPack?.id == pack.id

        return Button {
            guard purchaseState == .idle else { return }
            selectedPackID = pack.id
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(pack.displayName)
                            .font(.calm(18, weight: .heavy))
                            .foregroundColor(.white)

                        if let badge = pack.badgeText {
                            Text(badge)
                                .font(.calm(10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .frame(height: 22)
                                .background(Capsule().fill(Color(hex: "FF8D5E")))
                        }
                    }

                    Text(pack.coinsDescription)
                        .font(.calm(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.74))
                        .multilineTextAlignment(.leading)

                    if pack.bonusCoins > 0 {
                        Text("+\(pack.bonusCoins) bonus coins")
                            .font(.calm(13, weight: .bold))
                            .foregroundColor(Color(hex: "F5C94F"))
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(pack.displayPrice)
                        .font(.calm(22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text("\(pack.totalCoins) coins")
                        .font(.calm(13, weight: .bold))
                        .foregroundColor(.white.opacity(0.78))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color(hex: "2E6FA8").opacity(0.92) : Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color(hex: "6FCAFF") : Color.white.opacity(0.14), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(purchaseState != .idle)
    }

    private func syncSelectionIfNeeded() {
        if let selectedPackID,
           store.packages.contains(where: { $0.id == selectedPackID }) {
            return
        }
        selectedPackID = store.packages.first?.id
    }

    private func purchaseSelectedPack() {
        guard let selectedPack else { return }
        guard purchaseState == .idle else { return }

        Task {
            purchaseState = .processing
            do {
                try await store.purchase(pack: selectedPack, sessionManager: sessionManager) {
                    purchaseState = .verifying
                }
                onClose()
            } catch let error as CreditPurchaseStoreError {
                purchaseState = .idle
                if case .userCancelled = error {
                    return
                }
                feedbackMessage = error.errorDescription
            } catch {
                purchaseState = .idle
                feedbackMessage = error.localizedDescription
            }
        }
    }
}

private enum CreditPurchaseActionState: Equatable {
    case idle
    case processing
    case verifying
}

struct CreditPack: Identifiable, Equatable, Codable {
    let id: String
    let storeKitProductID: String
    let displayName: String
    let description: String
    let totalCoins: Int
    let bonusCoins: Int
    let bonusPercentage: Int
    let displayPrice: String
    let amount: Double?
    let currencyCode: String?
    let tags: [String]
    let sortOrder: Int

    var badgeText: String? {
        tags.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var coinsDescription: String {
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        if bonusCoins > 0 {
            return "Includes \(totalCoins) coins total"
        }
        return "Adds \(totalCoins) coins to your balance"
    }
}

private struct CreditPackResponse: Decodable {
    let success: Bool?
    let data: [CreditPackConfiguration]?
    let count: Int?
    let error: String?
}

private struct CreditPackConfiguration: Decodable {
    let id: String
    let productID: String
    let displayName: String?
    let description: String?
    let amount: Double?
    let currency: String?
    let baseCoins: Int?
    let bonusPercentage: Int?
    let bonusCoins: Int?
    let totalCoins: Int?
    let tags: [String]?
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case productID = "product_id"
        case displayName = "display_name"
        case description
        case amount
        case currency
        case baseCoins = "base_coins"
        case bonusPercentage = "bonus_percentage"
        case bonusCoins = "bonus_coins"
        case totalCoins = "total_coins"
        case tags
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        productID = (try? container.decode(String.self, forKey: .productID)) ?? ""
        displayName = try? container.decodeIfPresent(String.self, forKey: .displayName)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        amount = container.decodeLossyDoubleIfPresent(forKey: .amount)
        currency = try? container.decodeIfPresent(String.self, forKey: .currency)
        baseCoins = container.decodeLossyIntIfPresent(forKey: .baseCoins)
        bonusPercentage = container.decodeLossyIntIfPresent(forKey: .bonusPercentage)
        bonusCoins = container.decodeLossyIntIfPresent(forKey: .bonusCoins)
        totalCoins = container.decodeLossyIntIfPresent(forKey: .totalCoins)
        tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
        sortOrder = container.decodeLossyIntIfPresent(forKey: .sortOrder)
    }
}

private struct AppleIAPVerifyRequest: Encodable {
    let transactionId: String
    let signedTransactionInfo: String
    let signedRenewalInfo: String?
}

private struct AppleIAPVerifyResponse: Decodable {
    let success: Bool?
    let type: String?
    let productID: String?
    let creditsGranted: Int?
    let creditsBalance: Int?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case type
        case productID = "product_id"
        case creditsGranted = "credits_granted"
        case creditsBalance = "credits_balance"
        case message
        case error
    }
}

private enum CreditPurchaseStoreError: LocalizedError {
    case userCancelled
    case purchasePending
    case packagesUnavailable
    case missingProductInfo
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase cancelled"
        case .purchasePending:
            return "Your purchase is pending approval. Please try again in a moment."
        case .packagesUnavailable:
            return "Coin packages are unavailable right now."
        case .missingProductInfo:
            return "Product information is not available yet. Please try again shortly."
        case let .verificationFailed(message):
            return message.isEmpty ? "Coin purchase verification failed. Please try again." : message
        }
    }
}

@MainActor
final class CreditPurchaseStore: ObservableObject {
    static let shared = CreditPurchaseStore()

    @Published private(set) var packages: [CreditPack] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    private let apiClient: APIClient
    private let userDefaults: UserDefaults
    private let cacheKey = "glampro.credit_packs.cache"
    private var didLoadOnce = false
    private var productsByID: [String: Product] = [:]

    init(apiClient: APIClient = .shared, userDefaults: UserDefaults = .standard) {
        self.apiClient = apiClient
        self.userDefaults = userDefaults
        loadCachedPackages()
    }

    func preloadPackagesIfNeeded(force: Bool = false) async {
        if !force, didLoadOnce, !packages.isEmpty {
            return
        }

        let shouldShowLoading = packages.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        defer {
            if shouldShowLoading {
                isLoading = false
            }
        }

        do {
            let response: CreditPackResponse = try await apiClient.get(
                path: "iap-coin-packages",
                queryItems: [
                    URLQueryItem(name: "app_id", value: APIConfig.appID),
                    URLQueryItem(name: "platform", value: "apple")
                ]
            )

            let configs = (response.data ?? []).filter { !$0.productID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if configs.isEmpty {
                if packages.isEmpty {
                    packages = []
                    loadError = "No Apple coin packages are configured for this app yet."
                }
                didLoadOnce = true
                return
            }

            let productIDs = configs.map(\.productID)
            if let products = try? await Product.products(for: productIDs) {
                productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            }

            let resolvedPackages = configs
                .sorted { ($0.sortOrder ?? .max, $0.displayName ?? "") < ($1.sortOrder ?? .max, $1.displayName ?? "") }
                .map { makePack(from: $0, product: productsByID[$0.productID]) }

            packages = resolvedPackages
            persistPackages(resolvedPackages)
            loadError = nil
            didLoadOnce = true
        } catch is CancellationError {
            return
        } catch let error as APIError {
            if isCancellationLike(error) {
                return
            }
            if packages.isEmpty {
                loadError = error.localizedDescription
            }
            didLoadOnce = true
        } catch {
            if packages.isEmpty {
                loadError = error.localizedDescription
            }
            didLoadOnce = true
        }
    }

    func purchase(
        pack: CreditPack,
        sessionManager: SessionManager,
        onVerifying: @escaping @MainActor () -> Void
    ) async throws {
        if productsByID[pack.storeKitProductID] == nil {
            await preloadPackagesIfNeeded(force: true)
        }

        guard let product = productsByID[pack.storeKitProductID] else {
            throw CreditPurchaseStoreError.missingProductInfo
        }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                await onVerifying()
                try await verifyCreditPurchase(verification: verification, sessionManager: sessionManager)
            case .userCancelled:
                throw CreditPurchaseStoreError.userCancelled
            case .pending:
                throw CreditPurchaseStoreError.purchasePending
            }
        } catch let error as CreditPurchaseStoreError {
            throw error
        } catch let error as Product.PurchaseError {
            throw CreditPurchaseStoreError.verificationFailed(error.localizedDescription)
        } catch {
            throw CreditPurchaseStoreError.verificationFailed(error.localizedDescription)
        }
    }

    private func verifyCreditPurchase(
        verification: VerificationResult<StoreKit.Transaction>,
        sessionManager: SessionManager
    ) async throws {
        let transaction: StoreKit.Transaction
        do {
            transaction = try verification.payloadValue
        } catch {
            throw CreditPurchaseStoreError.verificationFailed("StoreKit could not verify this transaction.")
        }

        let body = AppleIAPVerifyRequest(
            transactionId: String(transaction.id),
            signedTransactionInfo: verification.jwsRepresentation,
            signedRenewalInfo: nil
        )

        let response: AppleIAPVerifyResponse = try await sessionManager.performAuthenticatedRequest { token in
            try await self.apiClient.post(
                path: "apple-iap-verify",
                body: body,
                bearerToken: token
            )
        }

        if response.success == false {
            throw CreditPurchaseStoreError.verificationFailed(response.message ?? response.error ?? "Coin purchase verification failed.")
        }

        let granted = max(response.creditsGranted ?? 0, 0)
        let newBalance = response.creditsBalance ?? (sessionManager.creditsBalance + granted)
        sessionManager.updateUserStatusFromCreditPurchase(credits: newBalance)
        await transaction.finish()
    }

    private func makePack(from config: CreditPackConfiguration, product: Product?) -> CreditPack {
        let totalCoins = config.totalCoins ?? ((config.baseCoins ?? 0) + (config.bonusCoins ?? 0))
        let displayName = config.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayPrice = product?.displayPrice
            ?? formatCurrency(config.amount, currencyCode: config.currency)
            ?? "--"

        return CreditPack(
            id: config.productID,
            storeKitProductID: config.productID,
            displayName: displayName?.isEmpty == false ? displayName! : "\(totalCoins) Coins",
            description: config.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            totalCoins: totalCoins,
            bonusCoins: config.bonusCoins ?? 0,
            bonusPercentage: config.bonusPercentage ?? 0,
            displayPrice: displayPrice,
            amount: config.amount,
            currencyCode: config.currency,
            tags: config.tags ?? [],
            sortOrder: config.sortOrder ?? .max
        )
    }

    private func loadCachedPackages() {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cachedPackages = try? JSONDecoder().decode([CreditPack].self, from: data),
              !cachedPackages.isEmpty else {
            return
        }
        packages = cachedPackages.sorted { ($0.sortOrder, $0.displayName) < ($1.sortOrder, $1.displayName) }
    }

    private func persistPackages(_ packages: [CreditPack]) {
        guard let data = try? JSONEncoder().encode(packages) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    private func formatCurrency(_ amount: Double?, currencyCode: String?) -> String? {
        guard let amount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = (currencyCode ?? "USD").uppercased()
        formatter.maximumFractionDigits = amount.rounded() == amount ? 0 : 2
        formatter.minimumFractionDigits = amount.rounded() == amount ? 0 : 2
        return formatter.string(from: NSNumber(value: amount))
    }

    private func isCancellationLike(_ error: APIError) -> Bool {
        if case let .transportError(message) = error {
            return message.localizedCaseInsensitiveContains("cancelled")
        }
        return false
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyDoubleIfPresent(forKey key: Key) -> Double? {
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }

    func decodeLossyIntIfPresent(forKey key: Key) -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }
}
