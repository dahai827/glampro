import SwiftUI

struct HomeView: View {
    private struct HomeBannerItem: Identifiable {
        enum Destination {
            case aiChat
            case customStyles
            case motionSwap
        }

        let id: String
        let title: String
        let videoURL: URL
        let destination: Destination
    }

    private struct ReviewLoginFeedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appBootstrap: AppBootstrapStore
    @EnvironmentObject private var savedTemplatesStore: SavedTemplatesStore
    @Environment(\.openURL) private var openURL
    @State private var selectedRemoteSection: RemoteFeatureSection?
    @State private var selectedShotsSectionID: String?
    @State private var reviewLoginTapCount = 0
    @State private var lastReviewLoginTapTime: Date = .distantPast
    @State private var showReviewLoginConfirm = false
    @State private var isReviewLoginLoading = false
    @State private var reviewLoginFeedback: ReviewLoginFeedback?
    @State private var selectedDiscoverIndex = 0

    let selectedSection: HomeSection
    let selectSection: (HomeSection) -> Void
    let openCredits: () -> Void
    let openSubscriptionPaywall: () -> Void
    let openProfile: () -> Void
    let openPreview: () -> Void
    let openCollection: (HomeCollectionPage) -> Void
    let openAIChat: () -> Void
    let openCustomStyles: () -> Void
    let openMotionSwap: () -> Void

    private let trendCardSpacing: CGFloat = 12
    private let trendCardPeekFraction: CGFloat = 2.0 / 3.0
    private let trendCardAspectRatio: CGFloat = 223.0 / 134.0
    private let trendCardCornerRadius: CGFloat = 18
    private let shotsCardHeightRatios: [CGFloat] = [1.49, 1.36, 1.19, 1.29, 1.16, 1.41]
    private let shotsCardMinHeight: CGFloat = 208
    private let shotsCardMaxHeight: CGFloat = 296
    private let shotsCardCornerRadius: CGFloat = 0
    private let shotsColumnSpacing: CGFloat = 0
    private let shotsCardSpacing: CGFloat = 0

    var body: some View {
        ScreenContainer(showBrand: false, bottomSpacing: selectedSection == .shots ? 116 : 102) {
            GlamProTheme.background
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                header
                    .padding(.horizontal, 16)

                if !appBootstrap.isReviewVersion {
                    filterRow
                        .padding(.horizontal, 16)
                }

                ScrollView(showsIndicators: false) {
                    contentBody
                        .padding(.horizontal, 16)
                }
            }
        }
        .fullScreenCover(item: $selectedRemoteSection) { section in
            RemoteFeatureCollectionPageView(
                section: section,
                onClose: { selectedRemoteSection = nil },
                onSelectItem: handleRemoteItemSelection
            )
        }
        .alert("Review Login", isPresented: $showReviewLoginConfirm) {
            Button("Cancel", role: .cancel) {
                reviewLoginTapCount = 0
            }
            Button(isReviewLoginLoading ? "Logging In..." : "Confirm") {
                performReviewLogin()
            }
        } message: {
            Text("Use the App Review account for this build?")
        }
        .alert(item: $reviewLoginFeedback) { feedback in
            Alert(
                title: Text(feedback.title),
                message: Text(feedback.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            if selectedSection == .new {
                selectSection(.all)
            }
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch selectedSection {
        case .saved:
            savedContent
        case .all:
            homeContent
        case .new:
            newContent
        case .shots:
            shotsContent
        }
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !appBootstrap.isReviewVersion {
                if discoverCarouselItems.isEmpty {
                    heroCard
                } else {
                    discoverCarousel
                }
            }

            if appBootstrap.videoSections.isEmpty {
                if appBootstrap.isReviewVersion {
                    reviewLoadingState(title: "Loading video templates...")
                } else {
                    fallbackHomeContent
                }
            } else {
                dynamicHomeContent
            }
        }
    }

    private var fallbackHomeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Viral Trends", actionTitle: "All", action: { openCollection(.viralTrends) })
                .padding(.top, 2)
            trendsRow(cards: MockData.trends)
            SectionHeader(title: "Spotlight", actionTitle: "All", action: { openCollection(.spotlight) })
                .padding(.top, 4)
            trendsRow(cards: MockData.spotlight)
        }
    }

    private var dynamicHomeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(appBootstrap.videoSections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(
                        title: section.displayTitle,
                        actionTitle: appBootstrap.isReviewVersion ? nil : (section.items.count > 2 ? "All" : nil),
                        action: {
                            if !appBootstrap.isReviewVersion {
                                selectedRemoteSection = section
                            }
                        }
                    )

                    if let subtitle = section.displaySubtitle,
                       subtitle.caseInsensitiveCompare(section.displayTitle) != .orderedSame {
                        Text(subtitle)
                            .font(.calm(13, weight: .medium))
                            .foregroundColor(GlamProTheme.secondaryText)
                            .padding(.top, -4)
                    }

                    if appBootstrap.isReviewVersion {
                        reviewSectionGrid(items: section.items)
                    } else {
                        remoteTrendsRow(items: section.items)
                    }
                }
            }
        }
    }

    private var reviewHomeGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12, alignment: .top),
            GridItem(.flexible(), spacing: 12, alignment: .top)
        ]
    }

    private func reviewSectionGrid(items: [RemoteFeatureItem]) -> some View {
        LazyVGrid(columns: reviewHomeGridColumns, spacing: 14) {
            ForEach(items) { item in
                ZStack(alignment: .topTrailing) {
                    Button {
                        handleRemoteItemSelection(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            ZStack(alignment: .topLeading) {
                                if let videoURL = item.coverVideoURL {
                                    RemoteLoopingVideoArtworkView(
                                        videoURL: videoURL,
                                        fallbackImageURL: item.effectiveCoverURL,
                                        paletteIndex: paletteIndex(for: item.id),
                                        cornerRadius: 14
                                    )
                                } else {
                                    RemoteArtworkView(
                                        url: item.effectiveCoverURL,
                                        paletteIndex: paletteIndex(for: item.id),
                                        cornerRadius: 14,
                                        contentMode: .fill
                                    )
                                }

                                if let badge = remoteBadgeText(for: item) {
                                    remoteBadge(title: badge)
                                        .padding(8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)

                            Text(item.title)
                                .font(.calm(13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(height: 34, alignment: .topLeading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    SavedTemplateBookmarkButton(item: item, iconSize: 14, padding: 10)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .id(itemViewIdentity(item))
            }
        }
    }

    private func reviewLoadingState(title: String) -> some View {
        VStack(alignment: .center, spacing: 10) {
            ProgressView()
                .tint(.white.opacity(0.9))
            Text(title)
                .font(.calm(14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var newContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            promoHero(
                title: "Just Dropped",
                subtitle: "Fresh styles curated for this week.",
                pillText: "6 New",
                paletteIndex: 7,
                symbol: "sparkles"
            )

            SectionHeader(title: "Fresh Picks", actionTitle: "All", action: { openCollection(.freshPicks) })
                .padding(.top, 2)
            trendsRow(cards: MockData.newDrops)

            SectionHeader(title: "Editor's Choice", actionTitle: "All", action: { openCollection(.editorsChoice) })
                .padding(.top, 4)
            trendsRow(cards: MockData.newHighlights)
        }
    }

    private var shotsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Shots")
                    .font(.calm(21, weight: .heavy))
                    .foregroundColor(.white)

                Text("Apply your face to fresh daily photos")
                    .font(.calm(14, weight: .medium))
                    .foregroundColor(GlamProTheme.secondaryText)
            }
            .padding(.top, 6)

            if appBootstrap.imageSections.isEmpty {
                if appBootstrap.isReviewVersion {
                    reviewLoadingState(title: "Loading image templates...")
                } else {
                    shotsCategoryRow
                    galleryGrid(
                        cards: scaledShotCards,
                        primaryBadgeTitle: "New",
                        primaryBadgeColor: GlamProTheme.pink,
                        secondaryBadgeTitle: "FREE",
                        secondaryBadgeColor: Color(hex: "FFB93A"),
                        trailingIcon: "bookmark"
                    )
                }
            } else {
                remoteShotsCategoryRow
                remoteGalleryGrid(items: activeShotsItems)
            }
        }
    }

    private var activeShotsSection: RemoteFeatureSection? {
        let visibleSections = visibleShotsSections
        if let selectedShotsSectionID,
           let matchedSection = visibleSections.first(where: { $0.id == selectedShotsSectionID }) {
            return matchedSection
        }

        return visibleSections.first
    }

    private var activeShotsItems: [RemoteFeatureItem] {
        activeShotsSection?.items ?? []
    }

    private var visibleShotsSections: [RemoteFeatureSection] {
        appBootstrap.imageSections.filter { section in
            let title = section.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return title != "frequently used"
        }
    }

    private var scaledShotCards: [ShotCardModel] {
        MockData.shotCards.enumerated().map { index, card in
            ShotCardModel(height: shotsCardHeight(for: index), paletteIndex: card.paletteIndex)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: handleReviewLoginTitleTap) {
                HStack(spacing: 8) {
                    Text("Glam Pro")
                        .font(.calm(26, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Button(action: openCredits) {
                    HStack(spacing: 7) {
                        Image(systemName: "c.circle.fill")
                            .font(.system(size: 17, weight: .black))
                        Text("\(sessionManager.creditsBalance)")
                            .font(.calm(17, weight: .bold))
                    }
                    .foregroundColor(appBootstrap.isReviewVersion ? .white : Color(hex: "F5C94F"))
                    .padding(.horizontal, appBootstrap.isReviewVersion ? 12 : 14)
                    .frame(height: appBootstrap.isReviewVersion ? 36 : 38)
                    .background(
                        reviewHeaderPillBackground(
                            isReviewVersion: appBootstrap.isReviewVersion,
                            fallback: GlamProTheme.goldGradient
                        )
                    )
                    .overlay(reviewHeaderPillBorder(isReviewVersion: appBootstrap.isReviewVersion))
                }
                .buttonStyle(.plain)

                Button(action: openSubscriptionPaywall) {
                    Text("PRO")
                        .font(.calm(17, weight: .bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundColor(appBootstrap.isReviewVersion ? .white : Color(hex: "F5C94F"))
                        .padding(.horizontal, appBootstrap.isReviewVersion ? 12 : 14)
                        .frame(height: appBootstrap.isReviewVersion ? 36 : 38)
                        .background(
                            reviewHeaderPillBackground(
                                isReviewVersion: appBootstrap.isReviewVersion,
                                fallback: GlamProTheme.goldGradient
                            )
                        )
                        .overlay(reviewHeaderPillBorder(isReviewVersion: appBootstrap.isReviewVersion))
                }
                .buttonStyle(.plain)
            }
            .layoutPriority(1)

            if !appBootstrap.isReviewVersion {
                CircleIconButton(
                    icon: "person.fill",
                    iconColor: .black,
                    backgroundColor: .white,
                    borderColor: Color.black.opacity(0.08),
                    action: openProfile
                )
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                homeFilterIconButton(icon: "bookmark.fill", isSelected: selectedSection == .saved) {
                    selectSection(.saved)
                }
                filterChip(title: "All", systemImage: "camera.macro", section: .all)
                filterChip(title: "Shots", systemImage: "calendar", section: .shots)
                ForEach(appBootstrap.videoSections) { section in
                    let tabTitle = section.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Video"
                        : section.displayTitle
                    Button {
                        selectedRemoteSection = section
                    } label: {
                        CapsuleChip(
                            title: tabTitle,
                            systemImage: "play.rectangle.fill",
                            badgeText: nil,
                            isSelected: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func reviewHeaderPillBackground(isReviewVersion: Bool, fallback: LinearGradient) -> some View {
        if isReviewVersion {
            Capsule().fill(Color.white.opacity(0.1))
        } else {
            Capsule().fill(fallback)
        }
    }

    @ViewBuilder
    private func reviewHeaderPillBorder(isReviewVersion: Bool) -> some View {
        Capsule()
            .stroke(isReviewVersion ? Color.white.opacity(0.2) : Color.white.opacity(0.07), lineWidth: 0.8)
    }

    private func filterChip(title: String, systemImage: String?, badgeText: String? = nil, section: HomeSection) -> some View {
        Button {
            selectSection(section)
        } label: {
            CapsuleChip(
                title: title,
                systemImage: systemImage,
                badgeText: badgeText,
                isSelected: selectedSection == section
            )
        }
        .buttonStyle(.plain)
    }

    private func homeFilterIconButton(icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.1))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.14 : 0.05), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    private enum SavedLayout {
        static let columnSpacing: CGFloat = 10
        static let cardSpacing: CGFloat = 14
        static let imageCornerRadius: CGFloat = 14
        static let titleHeight: CGFloat = 36
        static let metaHeight: CGFloat = 16
        static let imageHeightRatio: CGFloat = 1.56
    }

    private var savedGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: SavedLayout.columnSpacing, alignment: .top),
            GridItem(.flexible(), spacing: SavedLayout.columnSpacing, alignment: .top)
        ]
    }

    private var savedContent: some View {
        Group {
            if savedTemplatesStore.items.isEmpty {
                savedEmptyState
            } else {
                LazyVGrid(columns: savedGridColumns, spacing: SavedLayout.cardSpacing) {
                    ForEach(savedTemplatesStore.items) { item in
                        savedGridCard(item)
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
        }
    }

    private var savedEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)

            Text("No saved content yet")
                .font(.calm(20, weight: .heavy))
                .foregroundColor(.white)

            Text("Tap the bookmark on any template card and it will appear here.")
                .font(.calm(14, weight: .medium))
                .foregroundColor(GlamProTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                selectSection(.all)
            } label: {
                Text("Explore")
                    .font(.calm(16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 42)
                    .background(Capsule().fill(GlamProTheme.accentGradient))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 88)
    }

    private func savedGridCard(_ item: SavedTemplateItem) -> some View {
        let remoteItem = item.asRemoteFeatureItem

        return ZStack(alignment: .topTrailing) {
            Button {
                appBootstrap.selectPreviewItem(remoteItem)
                openPreview()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    ClippedArtworkContainer(cornerRadius: SavedLayout.imageCornerRadius) {
                        if let url = item.effectiveCoverURL {
                            RemoteArtworkView(
                                url: url,
                                paletteIndex: item.paletteIndex,
                                cornerRadius: SavedLayout.imageCornerRadius,
                                contentMode: .fill
                            )
                        } else {
                            PlaceholderArtwork(paletteIndex: item.paletteIndex, cornerRadius: SavedLayout.imageCornerRadius)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1 / SavedLayout.imageHeightRatio, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 5) {
                            if let badge = remoteItem.displayBadge {
                                Text(badge)
                                    .font(.calm(9, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .frame(height: 18)
                                    .background(Capsule().fill(GlamProTheme.pink))
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.38))
                                        .frame(width: 18, height: 18)
                                    Image(systemName: item.coverVideoURL != nil ? "play.fill" : "crown.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(7)
                    }

                    Text(item.title)
                        .font(.calm(13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(height: SavedLayout.titleHeight, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                savedTemplatesStore.toggle(item)
            } label: {
                Image(systemName: savedTemplatesStore.isSaved(item) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(9)
            }
            .buttonStyle(.plain)
        }
    }

    private var discoverCarouselItems: [HomeBannerItem] {
        localBannerItems
    }

    private var discoverCarouselCardHeight: CGFloat {
        let availableWidth = max(UIScreen.main.bounds.width - 32, 320)
        return min(max(availableWidth * 0.66, 224), 252)
    }

    private var discoverCarousel: some View {
        let items = localBannerItems
        return VStack(spacing: 10) {
            TabView(selection: $selectedDiscoverIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    discoverCarouselCard(item)
                        .tag(index)
                }
            }
            .frame(height: discoverCarouselCardHeight)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 9) {
                ForEach(Array(items.indices), id: \.self) { index in
                    Circle()
                        .fill(index == selectedDiscoverIndex ? Color.white.opacity(0.85) : Color.white.opacity(0.22))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .onChange(of: items.map(\.id)) { ids in
            guard !ids.isEmpty else {
                selectedDiscoverIndex = 0
                return
            }
            selectedDiscoverIndex = min(selectedDiscoverIndex, ids.count - 1)
        }
    }

    private func discoverCarouselCard(_ item: HomeBannerItem) -> some View {
        Button {
            handleLocalBannerTap(item)
        } label: {
            ZStack(alignment: .bottomLeading) {
                ClippedArtworkContainer(cornerRadius: 18) {
                    RemoteLoopingVideoArtworkView(
                        videoURL: item.videoURL,
                        fallbackImageURL: nil,
                        paletteIndex: paletteIndex(for: item.id),
                        cornerRadius: 18
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: discoverCarouselCardHeight)
                .overlay {
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.1), Color.black.opacity(0.52)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .id(item.id)
    }

    private var localBannerItems: [HomeBannerItem] {
        let configs: [(id: String, title: String, resourceName: String, ext: String, destination: HomeBannerItem.Destination)] = [
            ("local-banner-1", "AI Chat", "Banner Slider_1", "mp4", .aiChat),
            // Banner 2 temporarily hidden until new video is provided.
            ("local-banner-3", "Motion Swap", "Banner Slider_3", "mp4", .motionSwap)
        ]

        return configs.compactMap { config in
            let bundledURL =
                Bundle.main.url(forResource: config.resourceName, withExtension: config.ext, subdirectory: "Banner Slider")
                ?? Bundle.main.url(forResource: config.resourceName, withExtension: config.ext)

            guard let bundledURL else {
                print("[HomeView] missing bundled banner video: \(config.resourceName).\(config.ext)")
                return nil
            }

            return HomeBannerItem(id: config.id, title: config.title, videoURL: bundledURL, destination: config.destination)
        }
    }

    private func handleLocalBannerTap(_ item: HomeBannerItem) {
        switch item.destination {
        case .aiChat:
            openAIChat()
        case .customStyles:
            openCustomStyles()
        case .motionSwap:
            openMotionSwap()
        }
    }

    private func discoverCoverURL(for item: RemoteFeatureItem) -> URL? {
        let videoThumb = item.coverVideoThumbnailURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !videoThumb.isEmpty, let url = URL(string: videoThumb) {
            return url
        }
        return item.effectiveCoverURL
    }

    private var heroCard: some View {
        Button(action: openPreview) {
            VStack(spacing: 10) {
                PlaceholderArtwork(paletteIndex: 6, cornerRadius: 16)
                    .frame(height: 240)
                    .overlay(alignment: .bottomTrailing) {
                        Text("Try")
                            .font(.calm(17, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.trailing, 12)
                            .padding(.bottom, 14)
                    }

                HStack(spacing: 9) {
                    ForEach(0..<7, id: \.self) { index in
                        Circle()
                            .fill(index == 0 ? Color.white.opacity(0.8) : Color.white.opacity(0.22))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func promoHero(title: String, subtitle: String, pillText: String, paletteIndex: Int, symbol: String) -> some View {
        Button(action: openPreview) {
            PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: 18)
                .frame(height: 186)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Text(pillText)
                        .font(.calm(13, weight: .heavy))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.white.opacity(0.92)))
                        .padding(12)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.calm(22, weight: .heavy))
                                .foregroundColor(.white)
                            Text(subtitle)
                                .font(.calm(14, weight: .medium))
                                .foregroundColor(.white.opacity(0.92))
                        }

                        Spacer(minLength: 0)

                        Image(systemName: symbol)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white.opacity(0.94))
                    }
                    .padding(18)
                }
        }
        .buttonStyle(.plain)
    }

    private var shotsCategoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MockData.shotCategories, id: \.self) { category in
                    Text(category)
                        .font(.calm(15, weight: .bold))
                        .foregroundColor(category == "New" ? .black : .white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(
                            Capsule()
                                .fill(category == "New" ? Color.white : Color.white.opacity(0.09))
                        )
                }
            }
        }
    }

    private var remoteShotsCategoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(visibleShotsSections) { section in
                    let isSelected = section.id == activeShotsSection?.id

                    Button {
                        selectedShotsSectionID = section.id
                    } label: {
                        Text(section.displayTitle)
                            .font(.calm(15, weight: .bold))
                            .foregroundColor(isSelected ? .black : .white)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.09))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func galleryGrid(cards: [ShotCardModel], primaryBadgeTitle: String, primaryBadgeColor: Color, secondaryBadgeTitle: String, secondaryBadgeColor: Color, trailingIcon: String) -> some View {
        shotsWaterfallGrid(itemCount: cards.count) { index in
            let card = cards[index]

            Button(action: openPreview) {
                PlaceholderArtwork(paletteIndex: card.paletteIndex, cornerRadius: shotsCardCornerRadius)
                    .frame(maxWidth: .infinity)
                    .frame(height: card.height)
                    .clipShape(RoundedRectangle(cornerRadius: shotsCardCornerRadius, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 5) {
                            shotBadge(title: primaryBadgeTitle, fill: primaryBadgeColor, foreground: .white)
                            shotBadge(title: secondaryBadgeTitle, fill: secondaryBadgeColor, foreground: .white)
                        }
                        .padding(8)
                    }
                    .overlay(alignment: .topTrailing) {
                        if trailingIcon == "bookmark" {
                            let savedItem = SavedTemplateItem(mockCollectionCard: HomeCollectionCardModel(
                                title: "Saved Style",
                                author: secondaryBadgeTitle,
                                likesText: primaryBadgeTitle,
                                height: card.height,
                                paletteIndex: card.paletteIndex,
                                isNew: primaryBadgeTitle.caseInsensitiveCompare("new") == .orderedSame,
                                showsFeaturedMark: false
                            ))

                            Button {
                                savedTemplatesStore.toggle(savedItem)
                            } label: {
                                Image(systemName: savedTemplatesStore.isSaved(savedItem) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: trailingIcon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func remoteGalleryGrid(items: [RemoteFeatureItem]) -> some View {
        shotsWaterfallGrid(itemCount: items.count) { index in
            let item = items[index]

            ZStack(alignment: .topTrailing) {
                Button {
                    handleRemoteItemSelection(item)
                } label: {
                    ClippedArtworkContainer(cornerRadius: shotsCardCornerRadius) {
                        if let urls = shotsBeforeAfterURLs(for: item) {
                            HomeShotsBeforeAfterAutoView(
                                beforeURL: urls.before,
                                afterURL: urls.after,
                                fallbackURL: item.effectiveCoverURL,
                                paletteIndex: paletteIndex(for: item.id),
                                cornerRadius: shotsCardCornerRadius
                            )
                        } else {
                            RemoteArtworkView(
                                url: item.effectiveCoverURL,
                                paletteIndex: paletteIndex(for: item.id),
                                cornerRadius: shotsCardCornerRadius,
                                contentMode: .fill
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: remoteShotsCardHeight(for: index))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 5) {
                            shotBadge(
                                title: remoteShotsPrimaryBadgeText(for: item),
                                fill: remoteShotsPrimaryBadgeColor(for: item),
                                foreground: .white
                            )
                            if let requiredCoins = remoteShotsRequiredCoinsText(for: item) {
                                shotCoinBadge(requiredCoins)
                            } else {
                                shotBadge(
                                    title: "FREE",
                                    fill: Color(hex: "FFB93A"),
                                    foreground: .white
                                )
                            }
                        }
                        .padding(8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SavedTemplateBookmarkButton(item: item, iconSize: 15, padding: 10)
            }
        }
    }

    private func shotsBeforeAfterURLs(for item: RemoteFeatureItem) -> (before: URL, after: URL)? {
        guard
            let beforeString = item.previewConfig?.beforeImageURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
            let afterString = item.previewConfig?.afterImageURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
            !beforeString.isEmpty,
            !afterString.isEmpty,
            let beforeURL = URL(string: beforeString),
            let afterURL = URL(string: afterString)
        else {
            return nil
        }

        return (beforeURL, afterURL)
    }

    private func shotsWaterfallGrid<Content: View>(itemCount: Int, @ViewBuilder card: @escaping (Int) -> Content) -> some View {
        let leftColumnIndices = Array(stride(from: 0, to: itemCount, by: 2))
        let rightColumnIndices = Array(stride(from: 1, to: itemCount, by: 2))

        return HStack(alignment: .top, spacing: shotsColumnSpacing) {
            shotsWaterfallColumn(indices: leftColumnIndices, card: card)
            shotsWaterfallColumn(indices: rightColumnIndices, card: card)
        }
        .padding(.horizontal, -16)
        .padding(.bottom, 8)
    }

    private func shotsWaterfallColumn<Content: View>(indices: [Int], @ViewBuilder card: @escaping (Int) -> Content) -> some View {
        LazyVStack(spacing: shotsCardSpacing) {
            ForEach(indices, id: \.self) { index in
                card(index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func shotBadge(title: String, fill: Color, foreground: Color) -> some View {
        Text(title)
            .font(.calm(10, weight: .heavy))
            .foregroundColor(foreground)
            .padding(.horizontal, 7)
            .frame(height: 19)
            .background(Capsule().fill(fill))
    }

    private func shotCoinBadge(_ coinsText: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "F5C94F"))
            Text(coinsText)
                .font(.calm(10, weight: .heavy))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .frame(height: 19)
        .background(Capsule().fill(Color.black.opacity(0.35)))
    }

    private func remoteShotsCardHeight(for index: Int) -> CGFloat {
        shotsCardHeight(for: index)
    }

    private func shotsCardHeight(for index: Int) -> CGFloat {
        let ratio = shotsCardHeightRatios[index % shotsCardHeightRatios.count]
        let referenceScreenWidth = min(UIScreen.main.bounds.width, 430)
        let baseWidth = max(referenceScreenWidth / 2, 176)
        let height = round(baseWidth * ratio)
        return min(max(height, shotsCardMinHeight), shotsCardMaxHeight)
    }

    private func remoteShotsPrimaryBadgeText(for item: RemoteFeatureItem) -> String {
        remoteBadgeText(for: item) ?? "New"
    }

    private func remoteShotsPrimaryBadgeColor(for item: RemoteFeatureItem) -> Color {
        item.isAd ? Color(hex: "FF8A34") : GlamProTheme.pink
    }

    private func remoteShotsRequiredCoinsText(for item: RemoteFeatureItem) -> String? {
        let estimatedCredits = item.estimatedCredits ?? 0
        return estimatedCredits <= 0 ? nil : "\(estimatedCredits)"
    }

    private func remoteTrendsRow(items: [RemoteFeatureItem]) -> some View {
        GeometryReader { proxy in
            let cardWidth = trendCardWidth(in: proxy.size.width)
            let cardHeight = trendCardHeight(for: cardWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: trendCardSpacing) {
                    ForEach(items) { item in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                handleRemoteItemSelection(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .topLeading) {
                                        if let videoURL = item.coverVideoURL {
                                            RemoteLoopingVideoArtworkView(
                                                videoURL: videoURL,
                                                fallbackImageURL: item.effectiveCoverURL,
                                                paletteIndex: paletteIndex(for: item.id),
                                                cornerRadius: trendCardCornerRadius
                                            )
                                            .frame(width: cardWidth, height: cardHeight)
                                        } else {
                                            RemoteArtworkView(
                                                url: item.effectiveCoverURL,
                                                paletteIndex: paletteIndex(for: item.id),
                                                cornerRadius: trendCardCornerRadius,
                                                contentMode: .fill
                                            )
                                            .frame(width: cardWidth, height: cardHeight)
                                        }

                                        if let badge = remoteBadgeText(for: item) {
                                            remoteBadge(title: badge)
                                                .padding(8)
                                        } else {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(8)
                                        }
                                    }
                                    .frame(width: cardWidth, height: cardHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: trendCardCornerRadius, style: .continuous))
                                    .contentShape(RoundedRectangle(cornerRadius: trendCardCornerRadius, style: .continuous))

                                    Text(item.title)
                                        .font(.calm(13, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                .frame(width: cardWidth, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            SavedTemplateBookmarkButton(item: item, iconSize: 14, padding: 10)
                        }
                        .id(itemViewIdentity(item))
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .frame(height: trendRowHeight)
    }

    private func handleRemoteItemSelection(_ item: RemoteFeatureItem) {
        if item.isAd, let adURL = item.adIOSURL {
            openURL(adURL)
            return
        }

        appBootstrap.selectPreviewItem(item)

        if selectedRemoteSection != nil {
            selectedRemoteSection = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                openPreview()
            }
        } else {
            openPreview()
        }
    }

    private func handleReviewLoginTitleTap() {
        let now = Date()
        if now.timeIntervalSince(lastReviewLoginTapTime) > 2 {
            reviewLoginTapCount = 0
        }

        reviewLoginTapCount += 1
        lastReviewLoginTapTime = now

        if reviewLoginTapCount >= 10 {
            reviewLoginTapCount = 0
            showReviewLoginConfirm = true
        }
    }

    private func performReviewLogin() {
        guard !isReviewLoginLoading else { return }
        isReviewLoginLoading = true

        Task {
            do {
                try await sessionManager.reviewLogin()
                await MainActor.run {
                    isReviewLoginLoading = false
                    reviewLoginFeedback = ReviewLoginFeedback(
                        title: "Review Account Activated",
                        message: "The App Review account is now active on this device."
                    )
                }
            } catch {
                await MainActor.run {
                    isReviewLoginLoading = false
                    reviewLoginFeedback = ReviewLoginFeedback(
                        title: "Review Login Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func remoteBadgeText(for item: RemoteFeatureItem) -> String? {
        if item.isAd {
            return "AD"
        }
        return item.displayBadge
    }

    private func remoteBadge(title: String) -> some View {
        Text(title)
            .font(.calm(10, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Capsule().fill(GlamProTheme.pink))
    }

    private func paletteIndex(for seed: String) -> Int {
        abs(seed.hashValue) % 8
    }

    private func itemViewIdentity(_ item: RemoteFeatureItem) -> String {
        if let videoURL = item.coverVideoURL {
            return "\(item.id)-\(videoURL.absoluteString)"
        }
        return item.id
    }

    private func trendsRow(cards: [TrendCard]) -> some View {
        GeometryReader { proxy in
            let cardWidth = trendCardWidth(in: proxy.size.width)
            let cardHeight = trendCardHeight(for: cardWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: trendCardSpacing) {
                    ForEach(cards) { card in
                        Button(action: openPreview) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    PlaceholderArtwork(paletteIndex: card.paletteIndex, cornerRadius: trendCardCornerRadius)
                                        .frame(width: cardWidth, height: cardHeight)

                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(8)

                                    let savedItem = SavedTemplateItem(mockCollectionCard: HomeCollectionCardModel(
                                        title: card.title,
                                        author: card.subtitle,
                                        likesText: "",
                                        height: cardHeight,
                                        paletteIndex: card.paletteIndex,
                                        isNew: false,
                                        showsFeaturedMark: true
                                    ))

                                    Button {
                                        savedTemplatesStore.toggle(savedItem)
                                    } label: {
                                        Image(systemName: savedTemplatesStore.isSaved(savedItem) ? "bookmark.fill" : "bookmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(width: cardWidth, height: cardHeight)
                                .clipShape(RoundedRectangle(cornerRadius: trendCardCornerRadius, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: trendCardCornerRadius, style: .continuous))

                                Text(card.title)
                                    .font(.calm(13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(card.subtitle)
                                    .font(.calm(12, weight: .medium))
                                    .foregroundColor(GlamProTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            .frame(width: cardWidth, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .frame(height: trendRowHeight)
    }

    private func trendCardWidth(in availableWidth: CGFloat) -> CGFloat {
        let totalSpacing = trendCardSpacing * 2
        return ((availableWidth - totalSpacing) / (2 + trendCardPeekFraction)).rounded(.down)
    }

    private func trendCardHeight(for width: CGFloat) -> CGFloat {
        (width * trendCardAspectRatio).rounded(.down)
    }

    private var trendRowHeight: CGFloat {
        let availableWidth = UIScreen.main.bounds.width - 32
        let cardWidth = trendCardWidth(in: availableWidth)
        return trendCardHeight(for: cardWidth) + 46
    }
}


struct RemoteFeatureCollectionPageView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appBootstrap: AppBootstrapStore

    let section: RemoteFeatureSection
    let onClose: () -> Void
    let onSelectItem: (RemoteFeatureItem) -> Void

    private enum Layout {
        static let horizontalPadding: CGFloat = 6
        static let columnSpacing: CGFloat = 10
        static let cardSpacing: CGFloat = 14
        static let imageCornerRadius: CGFloat = 14
        static let topBarHeight: CGFloat = 34
        static let titleTopPadding: CGFloat = 4
        static let bottomPadding: CGFloat = 24
        static let titleHeight: CGFloat = 34
        static let metaHeight: CGFloat = 14
        static let imageHeightRatio: CGFloat = 1.56
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: Layout.columnSpacing, alignment: .top),
            GridItem(.flexible(), spacing: Layout.columnSpacing, alignment: .top)
        ]
    }

    var body: some View {
        ScreenContainer(showBrand: false, topSpacing: 10, bottomSpacing: 14) {
            GlamProTheme.background
        } content: {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                    topBar
                    collectionGrid
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, Layout.bottomPadding)
            }
        }
    }

    private var topBar: some View {
        ZStack {
            Text(section.displayTitle)
                .font(.calm(21, weight: .heavy))
                .foregroundColor(.white)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .frame(height: Layout.topBarHeight)
        .padding(.top, Layout.titleTopPadding)
    }

    private var collectionGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: Layout.cardSpacing) {
            ForEach(section.items) { item in
                collectionCard(item)
            }
        }
    }

    private func collectionCard(_ item: RemoteFeatureItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if item.isAd, let adURL = item.adIOSURL {
                    openURL(adURL)
                    return
                }
                appBootstrap.selectPreviewItem(item)
                onSelectItem(item)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    ClippedArtworkContainer(cornerRadius: Layout.imageCornerRadius) {
                        RemoteArtworkView(
                            url: item.effectiveCoverURL,
                            paletteIndex: abs(item.id.hashValue) % 8,
                            cornerRadius: Layout.imageCornerRadius,
                            contentMode: .fill
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1 / Layout.imageHeightRatio, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 5) {
                            if let badge = item.displayBadge ?? (item.isAd ? "AD" : nil) {
                                Text(badge)
                                    .font(.calm(9, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .frame(height: 18)
                                    .background(Capsule().fill(GlamProTheme.pink))
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.38))
                                        .frame(width: 18, height: 18)
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(7)
                    }

                    Text(item.title)
                        .font(.calm(13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(height: Layout.titleHeight, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            SavedTemplateBookmarkButton(item: item, iconSize: 13, padding: 9)
        }
    }
}


enum HomeCollectionPage {
    case viralTrends
    case spotlight
    case freshPicks
    case editorsChoice

    var title: String {
        switch self {
        case .viralTrends:
            return "Viral Trends"
        case .spotlight:
            return "Spotlight"
        case .freshPicks:
            return "Fresh Picks"
        case .editorsChoice:
            return "Editor's Choice"
        }
    }

    var cards: [HomeCollectionCardModel] {
        switch self {
        case .viralTrends:
            return MockData.viralTrendCollectionCards
        case .spotlight:
            return MockData.spotlightCollectionCards
        case .freshPicks:
            return MockData.freshPickCollectionCards
        case .editorsChoice:
            return MockData.editorsChoiceCollectionCards
        }
    }
}

private struct HomeShotsBeforeAfterAutoView: View {
    let beforeURL: URL
    let afterURL: URL
    let fallbackURL: URL?
    let paletteIndex: Int
    let cornerRadius: CGFloat

    @StateObject private var loader = HomeShotsBeforeAfterImageLoader()
    @State private var currentIndex = 0
    @State private var slideOffset: CGFloat = 0

    var body: some View {
        Group {
            if let beforeImage = loader.beforeImage, let afterImage = loader.afterImage {
                sliderContent(beforeImage: beforeImage, afterImage: afterImage)
            } else {
                RemoteArtworkView(
                    url: fallbackURL ?? beforeURL,
                    paletteIndex: paletteIndex,
                    cornerRadius: cornerRadius,
                    contentMode: .fill
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .topLeading) {
            cornerTag(title: loader.beforeImage != nil && loader.afterImage != nil ? (currentIndex == 0 ? "Before" : "After") : "Before")
                .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            cornerTag(title: loader.beforeImage != nil && loader.afterImage != nil ? (currentIndex == 0 ? "1/2" : "2/2") : "1/2")
                .padding(8)
        }
        .task(id: "\(beforeURL.absoluteString)|\(afterURL.absoluteString)") {
            await loader.load(beforeURL: beforeURL, afterURL: afterURL)
        }
    }

    private func sliderContent(beforeImage: UIImage, afterImage: UIImage) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            HStack(spacing: 0) {
                artwork(image: currentIndex == 0 ? beforeImage : afterImage)
                    .frame(width: width, height: proxy.size.height)
                artwork(image: currentIndex == 0 ? afterImage : beforeImage)
                    .frame(width: width, height: proxy.size.height)
            }
            .offset(x: -slideOffset)
            .onReceive(Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()) { _ in
                guard slideOffset == 0 else { return }
                withAnimation(.easeInOut(duration: 0.45)) {
                    slideOffset = width
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    currentIndex = (currentIndex + 1) % 2
                    slideOffset = 0
                }
            }
        }
    }

    private func artwork(image: UIImage) -> some View {
        ZStack {
            PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: cornerRadius)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    private func cornerTag(title: String) -> some View {
        Text(title)
            .font(.calm(10, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Color.black.opacity(0.35), in: Capsule())
    }
}

@MainActor
private final class HomeShotsBeforeAfterImageLoader: ObservableObject {
    @Published var beforeImage: UIImage?
    @Published var afterImage: UIImage?

    private var lastKey: String?
    private var loadingTask: Task<Void, Never>?

    func load(beforeURL: URL, afterURL: URL) async {
        let key = "\(beforeURL.absoluteString)|\(afterURL.absoluteString)"
        guard key != lastKey else { return }
        lastKey = key

        loadingTask?.cancel()
        beforeImage = nil
        afterImage = nil

        loadingTask = Task { [weak self] in
            async let before = Self.fetchImage(from: beforeURL)
            async let after = Self.fetchImage(from: afterURL)

            let (beforeResult, afterResult) = await (before, after)
            guard !Task.isCancelled else { return }

            self?.beforeImage = beforeResult
            self?.afterImage = afterResult
        }
    }

    private static func fetchImage(from url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

struct HomeCollectionPageView: View {
    @EnvironmentObject private var savedTemplatesStore: SavedTemplatesStore

    let page: HomeCollectionPage
    let onClose: () -> Void
    let openPreview: () -> Void

    private enum Layout {
        static let horizontalPadding: CGFloat = 6
        static let columnSpacing: CGFloat = 10
        static let cardSpacing: CGFloat = 14
        static let imageCornerRadius: CGFloat = 14
        static let topBarHeight: CGFloat = 34
        static let titleTopPadding: CGFloat = 4
        static let bottomPadding: CGFloat = 24
        static let titleHeight: CGFloat = 34
        static let metaHeight: CGFloat = 14
        static let imageHeightRatio: CGFloat = 1.56
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: Layout.columnSpacing, alignment: .top),
            GridItem(.flexible(), spacing: Layout.columnSpacing, alignment: .top)
        ]
    }

    var body: some View {
        ScreenContainer(showBrand: false, topSpacing: 10, bottomSpacing: 14) {
            GlamProTheme.background
        } content: {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                    topBar
                    collectionGrid
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, Layout.bottomPadding)
            }
        }
    }

    private var topBar: some View {
        ZStack {
            Text(page.title)
                .font(.calm(21, weight: .heavy))
                .foregroundColor(.white)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .frame(height: Layout.topBarHeight)
        .padding(.top, Layout.titleTopPadding)
    }

    private var collectionGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: Layout.cardSpacing) {
            ForEach(page.cards) { card in
                collectionCard(card)
            }
        }
    }

    private func collectionCard(_ card: HomeCollectionCardModel) -> some View {
        let savedItem = SavedTemplateItem(mockCollectionCard: card)

        return ZStack(alignment: .topTrailing) {
            Button(action: openPreview) {
                VStack(alignment: .leading, spacing: 6) {
                    ClippedArtworkContainer(cornerRadius: Layout.imageCornerRadius) {
                        PlaceholderArtwork(paletteIndex: card.paletteIndex, cornerRadius: Layout.imageCornerRadius)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1 / Layout.imageHeightRatio, contentMode: .fit)
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 5) {
                                if card.showsFeaturedMark {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.38))
                                            .frame(width: 18, height: 18)
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }

                                if card.isNew {
                                    Text("New")
                                        .font(.calm(9, weight: .heavy))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .frame(height: 18)
                                        .background(Capsule().fill(GlamProTheme.pink))
                                }
                            }
                            .padding(7)
                        }

                    Text(card.title)
                        .font(.calm(13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(height: Layout.titleHeight, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                savedTemplatesStore.toggle(savedItem)
            } label: {
                Image(systemName: savedTemplatesStore.isSaved(savedItem) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(9)
            }
            .buttonStyle(.plain)
        }
    }

}
