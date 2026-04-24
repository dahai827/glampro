import Foundation

@MainActor
final class AppBootstrapStore: ObservableObject {
    private static let reviewFontModeDefaultsKey = "glampro.review.font.mode"

    @Published private(set) var videoSections: [RemoteFeatureSection] = []
    @Published private(set) var imageSections: [RemoteFeatureSection] = []
    @Published private(set) var featureCards: [RemoteFeatureItem] = []
    @Published private(set) var isPreparing = false
    @Published private(set) var didPrepareOnce = false
    @Published private(set) var prepareErrorMessage: String?
    @Published private(set) var isReviewVersion = true
    @Published private(set) var reviewVersion: String?
    @Published var selectedPreviewItem: RemoteFeatureItem?

    var discoverItems: [RemoteFeatureItem] {
        var seenIDs = Set<String>()
        return Array(
            videoSections
                .flatMap(\.items)
                .filter { seenIDs.insert($0.id).inserted }
                .prefix(6)
        )
    }

    private let apiClient: APIClient
    private var isResolvingReviewVersion = false
    private var didResolveReviewVersion = false

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        Self.updateReviewFontMode(isReviewVersion)
    }

    func prepareIfNeeded(sessionManager: SessionManager) async {
        guard !didPrepareOnce, !isPreparing else { return }
        kickOffReviewVersionResolutionIfNeeded()
        Task { await SubscriptionStore.shared.preloadProducts() }
        Task { await CreditPurchaseStore.shared.preloadPackagesIfNeeded() }
        isPreparing = true
        defer { isPreparing = false }

        async let sessionTask: Void = sessionManager.bootstrapIfNeeded()
        async let videoTask = loadAllSections(menu: "video")
        async let imageTask = loadAllSections(menu: "image")
        async let gridTask = loadFeatureCards()

        do {
            let sections = try await videoTask
            let imageSections = try await imageTask
            let cards = try await gridTask
            videoSections = sections.sortedBySortOrder()
            self.imageSections = imageSections.sortedBySortOrder()
            featureCards = cards
            do {
                try await sessionTask
            } catch {
                print("[Bootstrap] session bootstrap failed: \(error.localizedDescription)")
            }
            didPrepareOnce = true
            prepareErrorMessage = nil
            print("[Bootstrap] prepared. video sections: \(sections.count), image sections: \(imageSections.count), grid items: \(cards.count)")
        } catch {
            prepareErrorMessage = error.localizedDescription
            do {
                try await sessionTask
            } catch {
                print("[Bootstrap] session bootstrap failed: \(error.localizedDescription)")
            }
            print("[Bootstrap] data preload failed: \(error.localizedDescription)")
        }
    }

    func refreshHomeData() async {
        kickOffReviewVersionResolutionIfNeeded(force: true)
        Task { await SubscriptionStore.shared.preloadProducts(force: true) }
        Task { await CreditPurchaseStore.shared.preloadPackagesIfNeeded(force: true) }
        do {
            videoSections = try await loadAllSections(menu: "video").sortedBySortOrder()
            imageSections = try await loadAllSections(menu: "image").sortedBySortOrder()
            featureCards = try await loadFeatureCards()
            prepareErrorMessage = nil
        } catch {
            prepareErrorMessage = error.localizedDescription
        }
    }

    func selectPreviewItem(_ item: RemoteFeatureItem) {
        selectedPreviewItem = item
    }

    private func kickOffReviewVersionResolutionIfNeeded(force: Bool = false) {
        guard force || !didResolveReviewVersion else { return }
        guard force || !isResolvingReviewVersion else { return }

        Task { [weak self] in
            await self?.resolveReviewVersionFromServer(force: force)
        }
    }

    private func resolveReviewVersionFromServer(force: Bool = false) async {
        guard force || !didResolveReviewVersion else { return }
        guard !isResolvingReviewVersion else { return }
        isResolvingReviewVersion = true
        defer { isResolvingReviewVersion = false }

        do {
            let response: AppNewVersionResponse = try await apiClient.get(
                path: "get-app-newversion",
                queryItems: [URLQueryItem(name: "app_id", value: APIConfig.appID)]
            )

            let serverVersion = response.reviewVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let currentVersion = APIConfig.appVersion.trimmingCharacters(in: .whitespacesAndNewlines)

            reviewVersion = serverVersion.isEmpty ? nil : serverVersion
            if response.success == true {
                isReviewVersion = !serverVersion.isEmpty && serverVersion == currentVersion
                Self.updateReviewFontMode(isReviewVersion)
                didResolveReviewVersion = true
                print("[Bootstrap] review version resolved. current: \(currentVersion), server: \(serverVersion.isEmpty ? "<empty>" : serverVersion), isReviewVersion: \(isReviewVersion)")
            } else if !didResolveReviewVersion {
                isReviewVersion = true
                Self.updateReviewFontMode(isReviewVersion)
                reviewVersion = nil
            }
        } catch {
            if !didResolveReviewVersion {
                isReviewVersion = true
                Self.updateReviewFontMode(isReviewVersion)
                reviewVersion = nil
            }
            print("[Bootstrap] review version resolve failed: \(error.localizedDescription). Keep review mode: \(isReviewVersion)")
        }
    }

    private static func updateReviewFontMode(_ isReviewVersion: Bool) {
        UserDefaults.standard.set(isReviewVersion, forKey: reviewFontModeDefaultsKey)
    }

    private func loadFeatureCards() async throws -> [RemoteFeatureItem] {
        let response: FeatureConfigsResponse = try await apiClient.get(
            path: "get-feature-configs",
            queryItems: [
                URLQueryItem(name: "app_id", value: APIConfig.appID),
                URLQueryItem(name: "page_type", value: APIConfig.defaultPageType),
                URLQueryItem(name: "menu", value: "grid"),
                URLQueryItem(name: "version", value: APIConfig.appVersion),
            ]
        )
        return response.sections.first?.items.sortedBySortOrder() ?? []
    }

    private func loadAllSections(menu: String) async throws -> [RemoteFeatureSection] {
        var sections: [RemoteFeatureSection] = []
        var nextCursor: String? = nil
        var shouldContinue = true

        while shouldContinue {
            let response: FeatureConfigsResponse = try await apiClient.get(
                path: "get-feature-configs",
                queryItems: featureQueryItems(menu: menu, cursor: nextCursor)
            )
            sections.append(contentsOf: response.sections)
            nextCursor = response.pagination?.nextCursor
            shouldContinue = response.pagination?.hasNext == true && nextCursor != nil
        }

        return sections
    }

    private func featureQueryItems(menu: String, cursor: String?) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "app_id", value: APIConfig.appID),
            URLQueryItem(name: "page_type", value: APIConfig.defaultPageType),
            URLQueryItem(name: "menu", value: menu),
            URLQueryItem(name: "version", value: APIConfig.appVersion),
            URLQueryItem(name: "limit", value: "10"),
        ]

        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }

        return items
    }
}

private extension Array where Element == RemoteFeatureSection {
    func sortedBySortOrder() -> [RemoteFeatureSection] {
        sorted {
            ($0.sortOrder ?? .max, $0.displayTitle) < ($1.sortOrder ?? .max, $1.displayTitle)
        }
    }
}

private extension Array where Element == RemoteFeatureItem {
    func sortedBySortOrder() -> [RemoteFeatureItem] {
        sorted {
            ($0.sortOrder ?? .max, $0.title) < ($1.sortOrder ?? .max, $1.title)
        }
    }
}


private struct AppNewVersionResponse: Decodable {
    let success: Bool?
    let appID: String?
    let reviewVersion: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case appID = "app_id"
        case reviewVersion = "review_version"
        case message
    }
}
