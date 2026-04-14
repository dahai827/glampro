import SwiftUI
import UIKit
import AppTrackingTransparency

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appBootstrap: AppBootstrapStore
    @EnvironmentObject private var previewGenerationStore: PreviewGenerationStore
    @StateObject private var dailyCheckinStore = DailyCheckinStore.shared
    @State private var selectedFeatureSection: RemoteFeatureSection?
    @State private var attRequestState: ATTRequestState = .idle

    private enum ATTRequestState {
        case idle
        case inFlight
        case decided
    }

    private static let attActivePollIntervalNs: UInt64 = 250_000_000
    private static let attActivePollMaxSteps = 80
    private static let attInitialDelayNs: UInt64 = 400_000_000

    var body: some View {
        ZStack(alignment: .bottom) {
            currentTabView
                .zIndex(0)

            if appState.shouldShowHomeBanner {
                FloatingPromoBanner(
                    title: "🎉 Free Generations 🎉",
                    subtitle: "No coins needed",
                    gradientColors: [Color(hex: "8E2DE2"), Color(hex: "B33AE6")],
                    shadowColor: Color(hex: "8E2DE2").opacity(0.24),
                    action: { appState.open(.subscriptionOne) },
                    onClose: appState.dismissHomeBanner
                )
                .frame(width: UIScreen.main.bounds.width * (2.0 / 3.0))
                .padding(.bottom, 76)
                .zIndex(5)
            }

            if !appState.showSplash && appState.activeRoute == nil {
                CustomTabBar(selectedTab: appState.selectedTab, shouldShowFeedBadge: appState.shouldShowFeedBadge) { tab in
                    appState.select(tab: tab)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
                .zIndex(6)
            }

            if appState.showRewardPopup {
                DailyRewardPopup(
                    status: dailyCheckinStore.status,
                    isClaiming: dailyCheckinStore.isSigning,
                    errorMessage: dailyCheckinStore.errorMessage,
                    onClose: appState.dismissReward,
                    onClaim: handleDailyRewardClaim
                )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }

            if appState.showFeaturesSheet {
                FeaturesView(
                    onSelectFeature: openFeatureFromSheet,
                    onSelectVideoSection: openVideoSectionFromSheet,
                    onClose: appState.dismissFeatures
                )
                .zIndex(12)
            }

            if let route = appState.activeRoute {
                routeView(route)
                    .zIndex(20)
            }

            if appState.showSplash {
                SplashScreenView()
                    .zIndex(30)
            }
        }
        .background(GlamProTheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.22), value: appState.activeRoute)
        .animation(.easeInOut(duration: 0.22), value: appState.selectedTab)
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: appState.showFeaturesSheet)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: appState.showRewardPopup)
        .onAppear {
            appState.startIfNeeded()
        }
        .task {
            await requestTrackingIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { @MainActor in
                await requestTrackingIfNeeded()
                FacebookAnalyticsService.shared.activateAppAfterTrackingBoundaryResolved()
                await refreshDailyCheckinStatusIfPossible(force: true)
            }
        }
        .task {
            await appBootstrap.prepareIfNeeded(sessionManager: sessionManager)
            maybePresentInitialSubscriptionPaywall()
            await refreshDailyCheckinStatusIfPossible()
        }
        .onChange(of: sessionManager.didFinishBootstrapAttempt) { _ in
            Task { @MainActor in
                await refreshDailyCheckinStatusIfPossible()
            }
        }
        .onChange(of: appState.showSplash) { _ in
            maybePresentInitialSubscriptionPaywall()
        }
        .onChange(of: sessionManager.didFinishBootstrapAttempt) { _ in
            maybePresentInitialSubscriptionPaywall()
        }
        .onChange(of: sessionManager.userStatus?.subscriptionStatus) { _ in
            maybePresentInitialSubscriptionPaywall()
        }
        .onChange(of: appState.activeRoute?.id) { _ in
            maybePresentInitialSubscriptionPaywall()
        }
        .fullScreenCover(item: $selectedFeatureSection) { section in
            RemoteFeatureCollectionPageView(
                section: section,
                onClose: { selectedFeatureSection = nil },
                onSelectItem: handleFeatureSectionItemSelection
            )
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch appState.selectedTab {
        case .home, .features:
            HomeView(
                selectedSection: appState.selectedHomeSection,
                selectSection: appState.select(homeSection:),
                openCredits: {
                    if sessionManager.isPro {
                        appState.open(.credits)
                    } else {
                        appState.open(.subscriptionTwo)
                    }
                },
                openProfile: { appState.open(.profile) },
                openPreview: { appState.open(.templatePreview) },
                openCollection: openHomeCollection,
                openAIChat: { appState.open(.aiChat) },
                openCustomStyles: { appState.open(.customStyles) },
                openMotionSwap: { appState.open(.motionSwap) }
            )
        case .feed:
            FeedView(
                openProfile: { appState.open(.profile) },
                openPreview: { appState.open(.templatePreview) }
            )
        }
    }

    private func maybePresentInitialSubscriptionPaywall() {
        guard !appState.showSplash else { return }
        guard sessionManager.didFinishBootstrapAttempt else { return }
        guard sessionManager.userStatus != nil else { return }
        guard !sessionManager.isPro else { return }
        guard appState.activeRoute == nil else { return }
        guard !appState.showFeaturesSheet else { return }
        appState.presentLaunchSubscriptionPaywallIfNeeded()
    }

    private func openHomeCollection(_ page: HomeCollectionPage) {
        switch page {
        case .viralTrends:
            appState.open(.viralTrends)
        case .spotlight:
            appState.open(.spotlight)
        case .freshPicks:
            appState.open(.freshPicks)
        case .editorsChoice:
            appState.open(.editorsChoice)
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .credits:
            CreditView(onClose: appState.dismissRoute, onGrabDeal: { appState.replace(with: .subscriptionTwo) })
        case .profile:
            ProfileView(onClose: appState.dismissRoute)
        case .aiChat:
            AIChatView(onClose: appState.dismissRoute)
        case .customStyles:
            CustomStylesView(onClose: appState.dismissRoute)
        case .motionSwap:
            MotionSwapView(onClose: appState.dismissRoute)
        case .uploadPhotos:
            UploadPhotosView(
                onClose: appState.dismissRoute,
                onGenerate: { appState.replace(with: .generationProgress) },
                onInsufficientCredits: {
                    if sessionManager.isPro {
                        appState.open(.credits)
                    } else {
                        appState.open(.subscriptionTwo)
                    }
                }
            )
        case .templatePreview:
            TemplatePreviewView(onClose: appState.dismissRoute, onCreate: {
                previewGenerationStore.beginEditing(item: appBootstrap.selectedPreviewItem)
                appState.open(.uploadPhotos)
            })
        case .generationProgress:
            GenerationProgressView(
                onClose: appState.dismissRoute,
                onShowResult: { appState.replace(with: .generationResult) }
            )
        case .generationResult:
            GenerationResultView(
                onClose: appState.dismissRoute,
                onGoToProfile: {
                    appState.replace(with: .profile)
                }
            )
        case .subscriptionOne:
            SubscriptionOfferOneView(onClose: appState.dismissRoute, onContinue: { appState.replace(with: .subscriptionTwo) })
        case .subscriptionTwo:
            SubscriptionOfferTwoView(
                onClose: appState.dismissRoute,
                onSubscribed: { appState.dismissRoute() }
            )
        case .viralTrends:
            HomeCollectionPageView(page: .viralTrends, onClose: appState.dismissRoute, openPreview: { appState.replace(with: .templatePreview) })
        case .spotlight:
            HomeCollectionPageView(page: .spotlight, onClose: appState.dismissRoute, openPreview: { appState.replace(with: .templatePreview) })
        case .freshPicks:
            HomeCollectionPageView(page: .freshPicks, onClose: appState.dismissRoute, openPreview: { appState.replace(with: .templatePreview) })
        case .editorsChoice:
            HomeCollectionPageView(page: .editorsChoice, onClose: appState.dismissRoute, openPreview: { appState.replace(with: .templatePreview) })
        }
    }

    private func openFeatureFromSheet(_ item: FeatureCardModel) {
        if item.title == "AI Chat" {
            appState.open(.aiChat)
        } else if item.title == "Custom Styles" {
            appState.open(.customStyles)
        } else if item.title == "Motion swap" {
            appState.open(.motionSwap)
        } else if item.title == "Shots" {
            appState.goHome(section: .shots)
        } else {
            appState.open(.templatePreview)
        }
    }

    private func openVideoSectionFromSheet(_ section: RemoteFeatureSection) {
        appState.dismissFeatures()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            selectedFeatureSection = section
        }
    }

    private func handleFeatureSectionItemSelection(_ item: RemoteFeatureItem) {
        if item.isAd, let adURL = item.adIOSURL {
            UIApplication.shared.open(adURL)
            return
        }

        appBootstrap.selectPreviewItem(item)
        selectedFeatureSection = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            appState.open(.templatePreview)
        }
    }

    private func handleDailyRewardClaim() {
        Task { @MainActor in
            await claimDailyReward()
        }
    }

    @MainActor
    private func claimDailyReward() async {
        let response = await dailyCheckinStore.signToday(sessionManager: sessionManager)
        appState.updateDailyRewardEligibility(
            dailyCheckinStore.canClaimToday,
            rewardDateKey: dailyCheckinStore.status?.today
        )
        guard response?.success == true else { return }
        let claimedDateKey = response?.checkinDate ?? dailyCheckinStore.status?.today
        appState.claimReward(claimedDateKey: claimedDateKey)
    }

    @MainActor
    private func refreshDailyCheckinStatusIfPossible(force: Bool = false) async {
        guard sessionManager.didFinishBootstrapAttempt else { return }
        await dailyCheckinStore.refreshStatus(sessionManager: sessionManager, force: force)
        appState.updateDailyRewardEligibility(
            dailyCheckinStore.canClaimToday,
            rewardDateKey: dailyCheckinStore.status?.today
        )
    }

    @MainActor
    private func requestTrackingIfNeeded() async {
        guard attRequestState == .idle else { return }

        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        print("[ATT] initial status: \(currentStatus.rawValue) (0=notDetermined 1=restricted 2=denied 3=authorized)")

        guard currentStatus == .notDetermined else {
            attRequestState = .decided
            FacebookAnalyticsService.shared.initializeIfNeeded()
            FacebookAnalyticsService.shared.updateATTStatus()
            FacebookAnalyticsService.shared.activateAppAfterTrackingBoundaryResolved()
            print("[ATT] tracking already decided: \(currentStatus.rawValue)")
            return
        }

        attRequestState = .inFlight
        try? await Task.sleep(nanoseconds: Self.attInitialDelayNs)

        let becameActive = await waitUntilApplicationIsActiveForATT()
        guard becameActive else {
            print("[ATT] wait active timeout, reset to idle")
            attRequestState = .idle
            return
        }

        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            attRequestState = .decided
            let status = ATTrackingManager.trackingAuthorizationStatus
            FacebookAnalyticsService.shared.initializeIfNeeded()
            FacebookAnalyticsService.shared.updateATTStatus()
            FacebookAnalyticsService.shared.activateAppAfterTrackingBoundaryResolved()
            print("[ATT] status changed before prompt: \(status.rawValue)")
            return
        }

        print("[ATT] requesting tracking authorization...")
        let result = await ATTrackingManager.requestTrackingAuthorization()
        print("[ATT] authorization result: \(result.rawValue)")

        if result == .notDetermined {
            attRequestState = .idle
            print("[ATT] result still notDetermined, will retry on next active")
            return
        }

        attRequestState = .decided
        FacebookAnalyticsService.shared.initializeIfNeeded()
        FacebookAnalyticsService.shared.updateATTStatus()
        FacebookAnalyticsService.shared.activateAppAfterTrackingBoundaryResolved()
    }

    @MainActor
    private func waitUntilApplicationIsActiveForATT() async -> Bool {
        for _ in 0..<Self.attActivePollMaxSteps {
            if UIApplication.shared.applicationState == .active {
                return true
            }
            try? await Task.sleep(nanoseconds: Self.attActivePollIntervalNs)
        }
        return UIApplication.shared.applicationState == .active
    }
}

private struct CustomTabBar: View {
    let selectedTab: AppTab
    let shouldShowFeedBadge: Bool
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            navItem(title: "Home", icon: "house.fill", tab: .home, badge: nil)
            Spacer(minLength: 0)
            plusButton
            Spacer(minLength: 0)
            navItem(title: "Feed", icon: "play.square.fill", tab: .feed, badge: shouldShowFeedBadge ? 1 : nil)
        }
        .frame(height: 74)
    }

    private func navItem(title: String, icon: String, tab: AppTab, badge: Int?) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.78))

                    if let badge {
                        Text("\(badge)")
                            .font(.calm(9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.red))
                            .offset(x: 8, y: -6)
                    }
                }

                Text(title)
                    .font(.calm(10, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.72))
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
    }

    private var plusButton: some View {
        Button {
            onSelect(.features)
        } label: {
            Circle()
                .fill(GlamProTheme.accentGradient)
                .frame(width: 56, height: 56)
                .shadow(color: GlamProTheme.pink.opacity(0.28), radius: 14, x: 0, y: 8)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FloatingPromoBanner: View {
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let shadowColor: Color
    let action: () -> Void
    var onClose: (() -> Void)? = nil

    private let bannerHeight: CGFloat = 60
    private let cornerRadius: CGFloat = 18

    var body: some View {
        ZStack(alignment: .leading) {
            Button(action: action) {
                VStack(spacing: 1) {
                    Text(title)
                        .font(.calm(15, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.calm(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: bannerHeight)
                .padding(.leading, onClose == nil ? 0 : 18)
                .padding(.trailing, 8)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
                .shadow(color: shadowColor, radius: 14, x: 0, y: 7)
            }
            .buttonStyle(.plain)

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.86))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.black.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .padding(.leading, 11)
            }
        }
    }
}

private struct DailyRewardPopup: View {
    let status: DailyCheckinStatusResponse?
    let isClaiming: Bool
    let errorMessage: String?
    let onClose: () -> Void
    let onClaim: () -> Void

    private let popupInnerHorizontalPadding: CGFloat = 22
    private let rewardRowBaseWidth: CGFloat = 332
    private let topCornerRadius: CGFloat = 28
    private let defaultRewards: [DailyCheckinReward] = [
        DailyCheckinReward(day: 1, credits: 10, status: "claimable"),
        DailyCheckinReward(day: 2, credits: 10, status: "locked"),
        DailyCheckinReward(day: 3, credits: 10, status: "locked"),
        DailyCheckinReward(day: 4, credits: 10, status: "locked"),
        DailyCheckinReward(day: 5, credits: 10, status: "locked"),
        DailyCheckinReward(day: 6, credits: 20, status: "locked"),
        DailyCheckinReward(day: 7, credits: 30, status: "locked")
    ]

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width
            let metrics = rewardMetrics(for: cardWidth)

            ZStack(alignment: .bottom) {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                popupCard(width: cardWidth, metrics: metrics, safeAreaBottom: proxy.safeAreaInsets.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func popupCard(width: CGFloat, metrics: RewardMetrics, safeAreaBottom: CGFloat) -> some View {
        VStack(spacing: 15) {
            Text("Come back daily for rewards")
                .font(.calm(20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("\(max(status?.currentStreakDay ?? 0, 0))-Day Streak")
                    .font(.calm(12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .overlay(Capsule().stroke(Color.white.opacity(0.68), lineWidth: 1))

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "E89B1B").opacity(0.34))
                        .frame(width: 196, height: 196)
                        .blur(radius: 28)

                    Circle()
                        .fill(Color(hex: "FFCF4B").opacity(0.16))
                        .frame(width: 136, height: 136)
                        .blur(radius: 8)

                    mainRewardCoinCluster
                }
                .frame(height: 154)

                Text("+\(claimableCredits) coins")
                    .font(.calm(27, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 4)
            .padding(.bottom, 4)

            HStack(alignment: .bottom, spacing: metrics.itemSpacing) {
                ForEach(rewardDays, id: \.id) { day in
                    rewardDay(
                        value: "\(day.credits)",
                        status: day.status,
                        isLarge: day.day == focusedDay,
                        metrics: metrics
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.calm(12, weight: .medium))
                    .foregroundColor(Color(hex: "FFB4A6"))
                    .multilineTextAlignment(.center)
            }

            Button(action: onClaim) {
                Text(isClaiming ? "Claiming..." : "Claim")
                    .font(.calm(17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: "FFD15B"), Color(hex: "F2B626")], startPoint: .leading, endPoint: .trailing))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isClaiming || !isClaimable)
            .opacity((isClaiming || !isClaimable) ? 0.72 : 1)
            .padding(.top, 2)
        }
        .padding(.horizontal, popupInnerHorizontalPadding)
        .padding(.bottom, max(safeAreaBottom, 16) + 14)
        .frame(width: width)
        .background {
            ZStack {
                TopSheetShape(radius: topCornerRadius)
                    .fill(Color(hex: "121212"))

                RadialGradient(
                    colors: [
                        Color(hex: "D58612").opacity(0.34),
                        Color(hex: "7A4306").opacity(0.22),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 16,
                    endRadius: 210
                )
                .offset(y: 20)
                .clipShape(TopSheetShape(radius: topCornerRadius))
            }
        }
        .overlay {
            TopSheetShape(radius: topCornerRadius)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: -2)
    }

    private func rewardDay(value: String, status: String, isLarge: Bool, metrics: RewardMetrics) -> some View {
        let badgeSize = isLarge ? metrics.largeCoinSize : metrics.smallCoinSize
        let iconSize = badgeSize * (isLarge ? 0.5 : 0.44)
        let lowerStatus = status.lowercased()
        let isLocked = lowerStatus == "locked"
        let isClaimable = lowerStatus == "claimable"
        let isSigned = lowerStatus == "signed" || lowerStatus == "signed_today"

        return ZStack {
            Circle()
                .fill(
                    isClaimable
                    ? Color(hex: "7E5A18")
                    : (isSigned ? Color(hex: "4A5421") : Color(hex: "4D401E"))
                )
                .opacity(isLocked ? 0.45 : 1)

            if isLarge {
                Circle()
                    .fill(Color(hex: "D79D2A").opacity(0.14))
                    .scaleEffect(0.92)
                    .blur(radius: 6)
            }

            VStack(spacing: isLarge ? 3 : 2) {
                rewardCoinFace(size: iconSize, showsLetter: true, emphasized: isLarge)

                Text(value)
                    .font(.calm(isLarge ? metrics.largeValueFontSize : metrics.smallValueFontSize, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .frame(width: badgeSize, height: badgeSize)
    }

    private var rewardDays: [DailyCheckinReward] {
        guard let dynamicRewards = status?.rewards, !dynamicRewards.isEmpty else {
            return defaultRewards
        }

        let rewardByDay = Dictionary(uniqueKeysWithValues: dynamicRewards.map { ($0.day, $0) })
        return (1...7).map { day in
            rewardByDay[day] ?? defaultRewards[max(0, min(day - 1, defaultRewards.count - 1))]
        }
    }

    private var claimableCredits: Int {
        let apiCredits = status?.claimableCredits ?? 0
        if apiCredits > 0 {
            return apiCredits
        }
        return rewardDays.first(where: { $0.status.lowercased() == "claimable" })?.credits ?? 10
    }

    private var focusedDay: Int {
        if let claimable = rewardDays.first(where: { $0.status.lowercased() == "claimable" })?.day {
            return claimable
        }
        if let signedToday = rewardDays.first(where: { $0.status.lowercased() == "signed_today" })?.day {
            return signedToday
        }
        if let status {
            if let claimableDay = status.claimableDay, (1...7).contains(claimableDay) {
                return claimableDay
            }
            let streakDay = status.currentStreakDay
            if (1...7).contains(streakDay) {
                return streakDay
            }
        }
        return 1
    }

    private var isClaimable: Bool {
        guard let status else { return true }
        return status.isActive && !status.signedToday && status.claimableDay != nil
    }

    private var mainRewardCoinCluster: some View {
        ZStack {
            stackedRewardCoins
                .offset(x: -10, y: 14)

            rewardCoinFace(size: 74, showsLetter: true, emphasized: true)
                .rotationEffect(.degrees(-7))
                .offset(x: 25, y: 16)
        }
        .frame(width: 196, height: 118)
    }

    private var stackedRewardCoins: some View {
        let xOffsets: [CGFloat] = [-2, 1, -1, 2]

        return ZStack {
            ForEach(0..<4, id: \.self) { index in
                stackedRewardCoin(size: 62)
                    .offset(x: xOffsets[index], y: CGFloat(index) * 10)
            }
        }
        .frame(width: 90, height: 98)
    }

    private func stackedRewardCoin(size: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.14))
                .frame(width: size * 0.9, height: size * 0.16)
                .blur(radius: 2.2)
                .offset(y: size * 0.2)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "985408"), Color(hex: "6F3600")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size * 0.28)
                .offset(y: size * 0.11)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFF0A6"), Color(hex: "F7C64A"), Color(hex: "D98A10")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size * 0.21)

            Capsule()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.52), Color.clear],
                        center: UnitPoint(x: 0.28, y: 0.2),
                        startRadius: 0,
                        endRadius: size * 0.34
                    )
                )
                .frame(width: size * 0.92, height: size * 0.16)
                .blendMode(.screen)
                .offset(x: -size * 0.04, y: -size * 0.015)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color(hex: "8C4700").opacity(0.34)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.9, height: size * 0.17)
                .offset(y: size * 0.02)

            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: size * 0.28, height: size * 0.035)
                .blur(radius: 0.9)
                .offset(x: -size * 0.15, y: -size * 0.045)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.12), radius: 2.6, x: 0, y: 1.6)
    }

    private func rewardCoinFace(size: CGFloat, showsLetter: Bool, emphasized: Bool = false) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(emphasized ? 0.18 : 0.14))
                .frame(width: size * 0.62, height: size * 0.18)
                .blur(radius: size * 0.045)
                .offset(y: size * 0.34)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "A65A07"), Color(hex: "733700")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .offset(y: size * 0.085)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFF1A8"), Color(hex: "F6C94A"), Color(hex: "D98A10")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(emphasized ? 0.64 : 0.52), Color(hex: "FFD968").opacity(0.72), Color.clear],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: size * 0.02,
                        endRadius: size * 0.44
                    )
                )
                .frame(width: size * 0.92, height: size * 0.92)
                .blendMode(.screen)
                .offset(x: -size * 0.03, y: -size * 0.03)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "8A4500").opacity(0.34), Color.clear],
                        center: UnitPoint(x: 0.74, y: 0.78),
                        startRadius: size * 0.02,
                        endRadius: size * 0.46
                    )
                )
                .frame(width: size * 0.94, height: size * 0.94)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(emphasized ? 0.22 : 0.18), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask(
                    Circle()
                        .strokeBorder(lineWidth: size * 0.08)
                        .blur(radius: size * 0.01)
                )
                .opacity(0.7)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(emphasized ? 0.42 : 0.32), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.44, height: size * 0.18)
                .blur(radius: size * 0.02)
                .offset(x: -size * 0.14, y: -size * 0.21)
                .rotationEffect(.degrees(-14))

            Ellipse()
                .fill(Color.white.opacity(0.12))
                .frame(width: size * 0.14, height: size * 0.06)
                .blur(radius: size * 0.012)
                .offset(x: size * 0.16, y: size * 0.02)

            if showsLetter {
                Text("G")
                    .font(.calm(size * 0.38, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "B66C00"), Color(hex: "7A3A00")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.white.opacity(0.18), radius: 0.8, x: -0.4, y: -0.4)
                    .shadow(color: Color(hex: "683000").opacity(0.28), radius: 0.8, x: 0.6, y: 0.9)
            }
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.18), radius: 4.2, x: 0, y: 2.6)
    }

    private func rewardMetrics(for cardWidth: CGFloat) -> RewardMetrics {
        let availableWidth = cardWidth - (popupInnerHorizontalPadding * 2)
        let scale = min(1.02, max(0.86, availableWidth / rewardRowBaseWidth))

        return RewardMetrics(
            smallCoinSize: 38 * scale,
            largeCoinSize: 56 * scale,
            itemSpacing: 8 * scale,
            smallCoinFontSize: 14 * scale,
            largeCoinFontSize: 24 * scale,
            smallValueFontSize: 11 * scale,
            largeValueFontSize: 22 * scale
        )
    }

    private struct RewardMetrics {
        let smallCoinSize: CGFloat
        let largeCoinSize: CGFloat
        let itemSpacing: CGFloat
        let smallCoinFontSize: CGFloat
        let largeCoinFontSize: CGFloat
        let smallValueFontSize: CGFloat
        let largeValueFontSize: CGFloat
    }
}

private struct TopSheetShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color(hex: "101010")
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(spacing: 10) {
                    BrandOrb(size: 44)
                    Text("Glam Pro")
                        .font(.calm(39, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text("AI Photo & Video Editor")
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.88))
                    .padding(.bottom, 84)
            }
        }
    }
}
