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
            let ctaHeight: CGFloat = 104

            ZStack(alignment: .bottom) {
                if appBootstrap.isReviewVersion {
                    VStack(spacing: 0) {
                        Spacer(minLength: max(geometry.size.height * 0.24, 190))

                        bottomPanel()
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.bottom, ctaHeight - 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    ctaBar(bottomInset: safeBottom)
                        .frame(height: ctaHeight)
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 6)
                        heroSection
                            .padding(.top, 42)
                            .padding(.bottom, 6)

                        bottomPanel()
                            .frame(maxHeight: .infinity)

                        ctaBar(bottomInset: safeBottom)
                            .frame(height: ctaHeight)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background {
                if appBootstrap.isReviewVersion {
                    SubscriptionPaywallVideoBackdropView(
                        isReviewVersion: true,
                        blurRadius: 22,
                        darkness: 0.42
                    )
                } else {
                    backgroundView
                }
            }
            .overlay(alignment: .top) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .zIndex(2)
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 24)
                .onEnded(handleGlobalSwipeToPurchase)
        )
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

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Image("CreditHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 356)
                .clipped()

            LinearGradient(
                colors: [Color.clear, Color(hex: "0F1A2A").opacity(0.56), Color(hex: "101824")],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 112)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 356)
        .clipped()
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "120F19"), Color(hex: "1B2A44"), Color(hex: "090B10")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(GlamProTheme.purple.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: -110, y: -220)

            Circle()
                .fill(GlamProTheme.orange.opacity(0.18))
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
        }
        .frame(maxWidth: .infinity)
    }

    private func bottomPanel() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glam Pro Credit Packs")
                    .font(.calm(30, weight: .heavy))
                    .foregroundColor(.white)

                Text("Choose your pack and swipe up to continue.")
                    .font(.calm(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

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
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color(hex: "101824").opacity(appBootstrap.isReviewVersion ? 0.68 : 0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(appBootstrap.isReviewVersion ? 0.08 : 0.1), lineWidth: 1)
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
                .foregroundColor(GlamProTheme.orange)

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
                            .fill(GlamProTheme.accentGradient)
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
                .foregroundColor(GlamProTheme.orange)

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
        VStack(spacing: 10) {
            ForEach(store.packages) { pack in
                packCard(pack)
            }
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("·")
                Link("Privacy", destination: URL(string: "http://www.streamflowai.store/glampro-privacy-policy.html")!)
            }
            .font(.calm(12, weight: .medium))
            .foregroundColor(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private func packCard(_ pack: CreditPack) -> some View {
        let isSelected = selectedPack?.id == pack.id

        return Button {
            guard purchaseState == .idle else { return }
            selectedPackID = pack.id
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(displayNameText(pack.displayName))
                        .font(.calm(25, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(displayPriceText(pack.displayPrice))
                            .font(.calm(21, weight: .regular))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if let original = originalPriceText(for: pack) {
                            Text(original)
                                .font(.calm(18, weight: .regular))
                                .foregroundColor(.white.opacity(0.56))
                                .strikethrough(true, color: .white.opacity(0.56))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Save 50%")
                    .font(.calm(10, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(Capsule().fill(Color(hex: "53A8FF")))
                    .offset(x: -12, y: -11)
            }
            .padding(.horizontal, 18)
            .padding(.top, 9)
            .padding(.bottom, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color(hex: "2E6FA8").opacity(0.95) : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color(hex: "6FCAFF") : Color.white.opacity(0.14), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(purchaseState != .idle)
    }

    private func ctaBar(bottomInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "101824"))
                .ignoresSafeArea(edges: .bottom)

            Button(action: purchaseSelectedPack) {
                VStack(spacing: 3) {
                    HStack(spacing: 8) {
                        if purchaseState != .idle {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text("Grab the deal")
                            .font(.calm(22, weight: .bold))
                    }
                    .foregroundColor(.white)

                    if purchaseState != .idle {
                        Text(continueButtonTitle)
                            .font(.calm(14, weight: .bold))
                            .foregroundColor(.white.opacity(0.94))
                    } else if let selectedPack {
                        Text("\(displayPriceText(selectedPack.displayPrice)) · Swipe up")
                            .font(.calm(14, weight: .medium))
                            .foregroundColor(.white.opacity(0.94))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .fill(canContinue ? GlamProTheme.accentGradient : LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.10)], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .padding(.bottom, max(bottomInset, 8))
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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

    private func handleGlobalSwipeToPurchase(_ value: DragGesture.Value) {
        guard canContinue else { return }
        let vertical = value.translation.height
        let horizontal = value.translation.width
        guard vertical < -90 else { return }
        guard abs(vertical) > (abs(horizontal) * 1.3) else { return }
        purchaseSelectedPack()
    }

    private func originalPriceText(for pack: CreditPack) -> String? {
        guard let amount = pack.amount, amount > 0 else { return nil }
        let originalAmount = amount * 2
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = (pack.currencyCode ?? "USD").uppercased()
        formatter.maximumFractionDigits = originalAmount.rounded() == originalAmount ? 0 : 2
        formatter.minimumFractionDigits = originalAmount.rounded() == originalAmount ? 0 : 2
        guard let raw = formatter.string(from: NSNumber(value: originalAmount)) else { return nil }
        return displayPriceText(raw)
    }

    private func displayPriceText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "US$", with: "$")
            .replacingOccurrences(of: "US", with: "")
    }

    private func displayNameText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard lower.hasPrefix("glampro") else { return trimmed }

        let suffix = trimmed.dropFirst("glampro".count).trimmingCharacters(in: .whitespacesAndNewlines)
        return suffix.isEmpty ? trimmed : suffix
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
    private let preferredProductIDs = [
        "glampro500coinspack",
        "glampro1700coinspack",
        "glampro6500coinspack"
    ]
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

            let apiConfigs = (response.data ?? []).filter { !$0.productID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let configs = resolveConfigurations(apiConfigs: apiConfigs)
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
                onVerifying()
                try await verifyCreditPurchase(verification: verification, sessionManager: sessionManager)
            case .userCancelled:
                throw CreditPurchaseStoreError.userCancelled
            case .pending:
                throw CreditPurchaseStoreError.purchasePending
            @unknown default:
                throw CreditPurchaseStoreError.verificationFailed("Purchase result is not supported on this iOS version.")
            }
        } catch let error as CreditPurchaseStoreError {
            throw error
        } catch let error as Product.PurchaseError {
            throw CreditPurchaseStoreError.verificationFailed(error.localizedDescription)
        } catch {
            throw CreditPurchaseStoreError.verificationFailed(error.localizedDescription)
        }
    }

    func handleTransactionUpdate(
        _ verification: VerificationResult<StoreKit.Transaction>,
        sessionManager: SessionManager
    ) async {
        do {
            try await verifyCreditPurchase(verification: verification, sessionManager: sessionManager)
            print("[StoreKit][Credits] handled transaction update")
        } catch {
            print("[StoreKit][Credits] transaction update handling failed: \(error.localizedDescription)")
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

    private func resolveConfigurations(apiConfigs: [CreditPackConfiguration]) -> [CreditPackConfiguration] {
        if apiConfigs.isEmpty {
            return fallbackConfigurations()
        }

        let fallbackByID = Dictionary(uniqueKeysWithValues: fallbackConfigurations().map { ($0.productID, $0) })
        let apiByID = Dictionary(uniqueKeysWithValues: apiConfigs.map { ($0.productID, $0) })

        var resolved: [CreditPackConfiguration] = []

        for (index, productID) in preferredProductIDs.enumerated() {
            if let apiConfig = apiByID[productID] {
                resolved.append(apiConfig.withSortOrder(index))
            } else if let fallbackConfig = fallbackByID[productID] {
                resolved.append(fallbackConfig.withSortOrder(index))
            }
        }

        let otherAPIConfigs = apiConfigs
            .filter { !preferredProductIDs.contains($0.productID) }
            .sorted { ($0.sortOrder ?? .max, $0.displayName ?? "") < ($1.sortOrder ?? .max, $1.displayName ?? "") }
        resolved.append(contentsOf: otherAPIConfigs)

        return resolved.isEmpty ? fallbackConfigurations() : resolved
    }

    private func fallbackConfigurations() -> [CreditPackConfiguration] {
        [
            CreditPackConfiguration(
                id: "fallback.glampro500coinspack",
                productID: "glampro500coinspack",
                displayName: "glampro 500 coins pack",
                description: "Add 500 coins to your balance.",
                amount: 14.99,
                currency: "USD",
                baseCoins: 500,
                bonusPercentage: 0,
                bonusCoins: 0,
                totalCoins: 500,
                tags: [],
                sortOrder: 0
            ),
            CreditPackConfiguration(
                id: "fallback.glampro1700coinspack",
                productID: "glampro1700coinspack",
                displayName: "glampro 1700 coins pack",
                description: "Add 1700 coins to your balance.",
                amount: 29.99,
                currency: "USD",
                baseCoins: 1700,
                bonusPercentage: 0,
                bonusCoins: 0,
                totalCoins: 1700,
                tags: ["Popular"],
                sortOrder: 1
            ),
            CreditPackConfiguration(
                id: "fallback.glampro6500coinspack",
                productID: "glampro6500coinspack",
                displayName: "glampro 6500 coins pack",
                description: "Add 6500 coins to your balance.",
                amount: 69.99,
                currency: "USD",
                baseCoins: 6500,
                bonusPercentage: 0,
                bonusCoins: 0,
                totalCoins: 6500,
                tags: ["Best"],
                sortOrder: 2
            )
        ]
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

private extension CreditPackConfiguration {
    init(
        id: String,
        productID: String,
        displayName: String?,
        description: String?,
        amount: Double?,
        currency: String?,
        baseCoins: Int?,
        bonusPercentage: Int?,
        bonusCoins: Int?,
        totalCoins: Int?,
        tags: [String]?,
        sortOrder: Int?
    ) {
        self.id = id
        self.productID = productID
        self.displayName = displayName
        self.description = description
        self.amount = amount
        self.currency = currency
        self.baseCoins = baseCoins
        self.bonusPercentage = bonusPercentage
        self.bonusCoins = bonusCoins
        self.totalCoins = totalCoins
        self.tags = tags
        self.sortOrder = sortOrder
    }

    func withSortOrder(_ sortOrder: Int) -> CreditPackConfiguration {
        CreditPackConfiguration(
            id: id,
            productID: productID,
            displayName: displayName,
            description: description,
            amount: amount,
            currency: currency,
            baseCoins: baseCoins,
            bonusPercentage: bonusPercentage,
            bonusCoins: bonusCoins,
            totalCoins: totalCoins,
            tags: tags,
            sortOrder: sortOrder
        )
    }
}
