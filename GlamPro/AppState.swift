import Foundation
import SwiftUI

struct DebugLaunchConfig {
    let tab: AppTab?
    let route: AppRoute?
    let forceRewardPopup: Bool
    let skipSplash: Bool
    let profileSegment: ProfileSegment?
    let homeSection: HomeSection?
    let uploadHasSelection: Bool
    let uploadShowsMenu: Bool

    static let current = DebugLaunchConfig()

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        tab = Self.value(for: "-calm-tab", in: arguments).flatMap(Self.parseTab)
        route = Self.value(for: "-calm-screen", in: arguments).flatMap(Self.parseRoute)
        forceRewardPopup = Self.flag("-calm-reward-popup", in: arguments)
        skipSplash = Self.flag("-calm-skip-splash", in: arguments)
        profileSegment = Self.value(for: "-calm-profile-segment", in: arguments).flatMap(Self.parseProfileSegment)
        homeSection = Self.value(for: "-calm-home-section", in: arguments).flatMap(Self.parseHomeSection)
        uploadHasSelection = Self.flag("-calm-upload-selected", in: arguments)
        uploadShowsMenu = Self.flag("-calm-upload-menu", in: arguments)
    }

    private static func value(for key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func flag(_ key: String, in arguments: [String]) -> Bool {
        arguments.contains(key)
    }

    private static func parseTab(_ rawValue: String) -> AppTab? {
        switch rawValue.lowercased() {
        case "home": return .home
        case "features": return .features
        case "feed": return .feed
        default: return nil
        }
    }

    private static func parseRoute(_ rawValue: String) -> AppRoute? {
        switch rawValue.lowercased() {
        case "credits": return .credits
        case "profile": return .profile
        case "aichat", "ai-chat", "ai_chat": return .aiChat
        case "customstyles", "custom-styles", "custom_styles", "createstyle", "create-style", "create_style": return .customStyles
        case "motionswap", "motion-swap", "motion_swap": return .motionSwap
        case "upload", "uploadphotos": return .uploadPhotos
        case "preview", "templatepreview": return .templatePreview
        case "progress", "generationprogress": return .generationProgress
        case "result", "generationresult": return .generationResult
        case "sub1", "subscription1", "subscriptionone": return .subscriptionOne
        case "sub2", "subscription2", "subscriptiontwo": return .subscriptionTwo
        case "viraltrends", "viral-trends": return .viralTrends
        case "spotlight": return .spotlight
        case "freshpicks", "fresh-picks": return .freshPicks
        case "editorschoice", "editor-choice", "editor's-choice": return .editorsChoice
        default: return nil
        }
    }

    private static func parseProfileSegment(_ rawValue: String) -> ProfileSegment? {
        switch rawValue.lowercased() {
        case "drafts": return .drafts
        case "posts": return .posts
        case "liked": return .liked
        case "saved": return .saved
        default: return nil
        }
    }

    private static func parseHomeSection(_ rawValue: String) -> HomeSection? {
        switch rawValue.lowercased() {
        case "saved": return .saved
        case "all": return .all
        case "new": return .new
        case "shots": return .shots
        default: return nil
        }
    }
}

enum AppTab {
    case home
    case features
    case feed
}

enum HomeSection {
    case saved
    case all
    case new
    case shots
}

enum AppRoute: String, Identifiable {
    case credits
    case profile
    case aiChat
    case customStyles
    case motionSwap
    case uploadPhotos
    case templatePreview
    case generationProgress
    case generationResult
    case subscriptionOne
    case subscriptionTwo
    case viralTrends
    case spotlight
    case freshPicks
    case editorsChoice

    var id: String { rawValue }
}

final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var selectedHomeSection: HomeSection = .all
    @Published var activeRoute: AppRoute?
    @Published var showRewardPopup = false
    @Published var showSplash = true
    @Published var showFeaturesSheet = false
    @Published var isHomeBannerDismissed = false
    @Published var shouldShowFeedBadge = false

    private var hasStarted = false
    private var didDismissRewardThisLaunch = false
    private var isDailyRewardEligible = false
    private var currentRewardDateKey: String?
    private let debugLaunchConfig = DebugLaunchConfig.current
    private var routeStack: [AppRoute] = []
    private var didPresentLaunchSubscriptionPaywall = false
    private let rewardClaimedDateDefaultsKey = "glampro.dailyCheckin.claimedDate"
    private let feedBadgeDismissedDateDefaultsKey = "glampro.feed.badge.dismissedDate"
    private let userDefaults = UserDefaults.standard

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        refreshFeedBadgeVisibilityForToday()

        if let tab = debugLaunchConfig.tab {
            if tab == .features {
                showFeaturesSheet = true
            } else {
                selectedTab = tab
            }
        }

        if let homeSection = debugLaunchConfig.homeSection {
            selectedHomeSection = homeSection
        }

        if let route = debugLaunchConfig.route {
            routeStack.removeAll()
            activeRoute = route
        }

        if debugLaunchConfig.skipSplash {
            showSplash = false
            showRewardPopup = debugLaunchConfig.forceRewardPopup && debugLaunchConfig.route == nil
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showSplash = false
            }
            if self.debugLaunchConfig.forceRewardPopup {
                self.showRewardPopup = true
            } else {
                self.presentDailyRewardIfNeeded()
            }
        }
    }

    func select(tab: AppTab) {
        if tab == .features {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                showFeaturesSheet = true
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            selectedTab = tab
            if tab == .home {
                selectedHomeSection = .all
            }
            showFeaturesSheet = false
        }

        if tab == .feed {
            dismissFeedBadgeForToday()
        }

        if tab == .home {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.presentDailyRewardIfNeeded()
            }
        }
    }

    func select(homeSection: HomeSection) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedHomeSection = homeSection
        }
    }

    func goHome() {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedTab = .home
            selectedHomeSection = .all
            showFeaturesSheet = false
            routeStack.removeAll()
            activeRoute = nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.presentDailyRewardIfNeeded()
        }
    }

    func goHome(section: HomeSection) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedTab = .home
            selectedHomeSection = section
            showFeaturesSheet = false
            routeStack.removeAll()
            activeRoute = nil
        }
    }

    func open(_ route: AppRoute) {
        withAnimation(.easeInOut(duration: 0.25)) {
            showFeaturesSheet = false

            if let activeRoute {
                routeStack.append(activeRoute)
            } else {
                routeStack.removeAll()
            }

            activeRoute = route
        }
    }

    func replace(with route: AppRoute) {
        withAnimation(.easeInOut(duration: 0.25)) {
            showFeaturesSheet = false

            if activeRoute == nil {
                routeStack.removeAll()
            }

            activeRoute = route
        }
    }

    func dismissRoute() {
        withAnimation(.easeInOut(duration: 0.25)) {
            activeRoute = routeStack.popLast()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            self.presentDailyRewardIfNeeded()
        }
    }

    func presentLaunchSubscriptionPaywallIfNeeded() {
        guard !didPresentLaunchSubscriptionPaywall else { return }
        didPresentLaunchSubscriptionPaywall = true

        withAnimation(.easeInOut(duration: 0.25)) {
            showRewardPopup = false
            showFeaturesSheet = false
            routeStack.removeAll()
            activeRoute = .subscriptionTwo
        }
    }

    func dismissFeatures() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            showFeaturesSheet = false
        }
    }

    func claimReward(claimedDateKey: String?) {
        isDailyRewardEligible = false
        didDismissRewardThisLaunch = true
        if let claimedDateKey, !claimedDateKey.isEmpty {
            userDefaults.set(claimedDateKey, forKey: rewardClaimedDateDefaultsKey)
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            showRewardPopup = false
        }
    }

    func dismissReward() {
        didDismissRewardThisLaunch = true
        withAnimation(.easeInOut(duration: 0.2)) {
            showRewardPopup = false
        }
    }

    func dismissHomeBanner() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isHomeBannerDismissed = true
        }
    }

    var shouldShowHomeBanner: Bool {
        false
    }

    func updateDailyRewardEligibility(_ eligible: Bool, rewardDateKey: String?) {
        currentRewardDateKey = rewardDateKey
        isDailyRewardEligible = eligible && !isClaimedForCurrentRewardDate
        if !eligible {
            showRewardPopup = false
            return
        }
        presentDailyRewardIfNeeded()
    }

    private func presentDailyRewardIfNeeded() {
        guard selectedTab == .home, activeRoute == nil, !showSplash, !showFeaturesSheet else { return }
        guard isDailyRewardEligible else { return }
        guard !didDismissRewardThisLaunch else { return }
        guard !isClaimedForCurrentRewardDate else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            showRewardPopup = true
        }
    }

    private var isClaimedForCurrentRewardDate: Bool {
        guard let currentRewardDateKey, !currentRewardDateKey.isEmpty else { return false }
        let claimedDate = userDefaults.string(forKey: rewardClaimedDateDefaultsKey)
        return claimedDate == currentRewardDateKey
    }

    private func refreshFeedBadgeVisibilityForToday() {
        let todayKey = currentLocalDateKey()
        let dismissedDate = userDefaults.string(forKey: feedBadgeDismissedDateDefaultsKey)
        shouldShowFeedBadge = dismissedDate != todayKey
    }

    private func dismissFeedBadgeForToday() {
        let todayKey = currentLocalDateKey()
        userDefaults.set(todayKey, forKey: feedBadgeDismissedDateDefaultsKey)
        shouldShowFeedBadge = false
    }

    private func currentLocalDateKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}


struct SavedTemplateItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let modelType: String?
    let modelID: String?
    let iconURLString: String?
    let coverImageURLString: String?
    let coverVideoURLString: String?
    let coverVideoThumbnailURLString: String?
    let previewStyle: String?
    let isAd: Bool?
    let adIOSURLString: String?
    let badge: String?
    let cardType: String?
    let textMode: String?
    let textImageURLString: String?
    let sortOrder: Int?
    let requiresPreview: Bool?
    let estimatedCredits: Int?
    let scene: String?
    let template: String?
    let promptTemplate: String?
    let enableImageMerge: Bool?
    let previewConfig: RemotePreviewConfig?
    let materialRequirements: [RemoteMaterialRequirement]?
    let previewTitle: String?
    let previewDescription: String?
    let savedAt: Date

    init(item: RemoteFeatureItem, savedAt: Date = Date()) {
        id = item.id
        title = item.title
        subtitle = item.subtitle
        modelType = item.modelType
        modelID = item.modelID
        iconURLString = item.iconURLString
        coverImageURLString = item.coverImageURLString
        coverVideoURLString = item.coverVideoURLString
        coverVideoThumbnailURLString = item.coverVideoThumbnailURLString
        previewStyle = item.previewStyle
        isAd = item.isAd
        adIOSURLString = item.adIOSURLString
        badge = item.badge
        cardType = item.cardType
        textMode = item.textMode
        textImageURLString = item.textImageURLString
        sortOrder = item.sortOrder
        requiresPreview = item.requiresPreview
        estimatedCredits = item.estimatedCredits
        scene = item.scene
        template = item.template
        promptTemplate = item.promptTemplate
        enableImageMerge = item.enableImageMerge
        previewConfig = item.previewConfig
        materialRequirements = item.materialRequirements
        previewTitle = item.previewConfig?.title
        previewDescription = item.previewConfig?.description
        self.savedAt = savedAt
    }

    var effectiveCoverURL: URL? {
        let primary = coverImageURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primary.isEmpty, let url = URL(string: primary) {
            return url
        }

        let fallback = coverVideoThumbnailURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fallback.isEmpty, let url = URL(string: fallback) {
            return url
        }

        return nil
    }

    var coverVideoURL: URL? {
        let value = coverVideoURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }

    var paletteIndex: Int {
        abs(id.hashValue) % 8
    }
}

@MainActor
final class SavedTemplatesStore: ObservableObject {
    @Published private(set) var items: [SavedTemplateItem] = []

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "\(APIConfig.appID).savedTemplates"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadPersistedItems()
    }

    func isSaved(_ item: RemoteFeatureItem?) -> Bool {
        guard let item else { return false }
        return items.contains(where: { $0.id == item.id })
    }

    func isSaved(_ item: SavedTemplateItem?) -> Bool {
        guard let item else { return false }
        return isSaved(id: item.id)
    }

    func isSaved(id: String) -> Bool {
        items.contains(where: { $0.id == id })
    }

    func toggle(_ item: RemoteFeatureItem) {
        guard !item.isAd else { return }
        toggle(SavedTemplateItem(item: item))
    }

    func toggle(_ item: SavedTemplateItem) {
        if isSaved(id: item.id) {
            remove(id: item.id)
        } else {
            save(item)
        }
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        persistItems()
    }

    private func save(_ item: SavedTemplateItem) {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        persistItems()
    }

    private func loadPersistedItems() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        if let savedItems = try? decoder.decode([SavedTemplateItem].self, from: data) {
            items = savedItems.sorted { $0.savedAt > $1.savedAt }
        }
    }

    private func persistItems() {
        guard let data = try? encoder.encode(items) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}


@MainActor
final class LikedTemplatesStore: ObservableObject {
    @Published private(set) var items: [SavedTemplateItem] = []

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "\(APIConfig.appID).likedTemplates"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadPersistedItems()
    }

    func isLiked(_ item: RemoteFeatureItem?) -> Bool {
        guard let item else { return false }
        return items.contains(where: { $0.id == item.id })
    }

    func isLiked(id: String) -> Bool {
        items.contains(where: { $0.id == id })
    }

    func toggle(_ item: RemoteFeatureItem) {
        guard !item.isAd else { return }

        if isLiked(id: item.id) {
            remove(id: item.id)
        } else {
            like(item)
        }
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        persistItems()
    }

    private func like(_ item: RemoteFeatureItem) {
        items.removeAll { $0.id == item.id }
        items.insert(SavedTemplateItem(item: item), at: 0)
        persistItems()
    }

    private func loadPersistedItems() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        if let likedItems = try? decoder.decode([SavedTemplateItem].self, from: data) {
            items = likedItems.sorted { $0.savedAt > $1.savedAt }
        }
    }

    private func persistItems() {
        guard let data = try? encoder.encode(items) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}


struct SavedTemplateBookmarkButton: View {
    @EnvironmentObject private var savedTemplatesStore: SavedTemplatesStore

    let item: RemoteFeatureItem
    var iconSize: CGFloat = 14
    var padding: CGFloat = 10

    var body: some View {
        Button {
            savedTemplatesStore.toggle(item)
        } label: {
            Image(systemName: savedTemplatesStore.isSaved(item) ? "bookmark.fill" : "bookmark")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
                .padding(padding)
        }
        .buttonStyle(.plain)
    }
}


struct LikedTemplateHeartButton: View {
    @EnvironmentObject private var likedTemplatesStore: LikedTemplatesStore

    let item: RemoteFeatureItem
    var iconSize: CGFloat = 24
    var padding: CGFloat = 0

    var body: some View {
        Button {
            likedTemplatesStore.toggle(item)
        } label: {
            Image(systemName: likedTemplatesStore.isLiked(item) ? "heart.fill" : "heart")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(.white)
                .padding(padding)
        }
        .buttonStyle(.plain)
    }
}


extension SavedTemplateItem {
    var asRemoteFeatureItem: RemoteFeatureItem {
        RemoteFeatureItem(savedItem: self)
    }
}

extension SavedTemplateItem {
    init(mockCollectionCard: HomeCollectionCardModel, savedAt: Date = Date()) {
        id = "mock.collection.\(mockCollectionCard.title)|\(mockCollectionCard.author)"
        title = mockCollectionCard.title
        subtitle = mockCollectionCard.author
        modelType = nil
        modelID = nil
        iconURLString = nil
        coverImageURLString = nil
        coverVideoURLString = nil
        coverVideoThumbnailURLString = nil
        previewStyle = nil
        isAd = false
        adIOSURLString = nil
        badge = mockCollectionCard.isNew ? "New" : nil
        cardType = nil
        textMode = nil
        textImageURLString = nil
        sortOrder = nil
        requiresPreview = false
        estimatedCredits = nil
        scene = mockCollectionCard.author
        template = nil
        promptTemplate = nil
        enableImageMerge = nil
        previewConfig = RemotePreviewConfig(
            beforeImageURLString: nil,
            afterImageURLString: nil,
            title: mockCollectionCard.title,
            description: mockCollectionCard.author
        )
        materialRequirements = []
        previewTitle = mockCollectionCard.title
        previewDescription = mockCollectionCard.author
        self.savedAt = savedAt
    }
}

extension SavedTemplateItem {
    init(mockFeedCard: FeedCardModel, savedAt: Date = Date()) {
        id = "mock.feed.\(mockFeedCard.title)|\(mockFeedCard.author)"
        title = mockFeedCard.title
        subtitle = mockFeedCard.author
        modelType = nil
        modelID = nil
        iconURLString = nil
        coverImageURLString = nil
        coverVideoURLString = nil
        coverVideoThumbnailURLString = nil
        previewStyle = nil
        isAd = false
        adIOSURLString = nil
        badge = nil
        cardType = nil
        textMode = nil
        textImageURLString = nil
        sortOrder = nil
        requiresPreview = false
        estimatedCredits = nil
        scene = mockFeedCard.author
        template = nil
        promptTemplate = nil
        enableImageMerge = nil
        previewConfig = RemotePreviewConfig(
            beforeImageURLString: nil,
            afterImageURLString: nil,
            title: mockFeedCard.title,
            description: mockFeedCard.author
        )
        materialRequirements = []
        previewTitle = mockFeedCard.title
        previewDescription = mockFeedCard.author
        self.savedAt = savedAt
    }
}

extension RemoteFeatureItem {
    init(savedItem: SavedTemplateItem) {
        let resolvedPreviewConfig = savedItem.previewConfig ?? RemotePreviewConfig(
            beforeImageURLString: nil,
            afterImageURLString: nil,
            title: savedItem.previewTitle,
            description: savedItem.previewDescription
        )

        id = savedItem.id
        title = savedItem.title
        subtitle = savedItem.subtitle
        modelType = savedItem.modelType
        modelID = savedItem.modelID
        iconURLString = savedItem.iconURLString
        coverImageURLString = savedItem.coverImageURLString
        coverVideoURLString = savedItem.coverVideoURLString
        coverVideoThumbnailURLString = savedItem.coverVideoThumbnailURLString
        previewStyle = savedItem.previewStyle
        isAd = savedItem.isAd ?? false
        adIOSURLString = savedItem.adIOSURLString
        badge = savedItem.badge
        cardType = savedItem.cardType
        textMode = savedItem.textMode
        textImageURLString = savedItem.textImageURLString
        sortOrder = savedItem.sortOrder
        requiresPreview = savedItem.requiresPreview
        estimatedCredits = savedItem.estimatedCredits
        scene = savedItem.scene
        template = savedItem.template
        promptTemplate = savedItem.promptTemplate
        enableImageMerge = savedItem.enableImageMerge
        previewConfig = resolvedPreviewConfig
        materialRequirements = savedItem.materialRequirements ?? []
    }
}
