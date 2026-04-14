import SwiftUI
import AVFoundation
import Photos
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appBootstrap: AppBootstrapStore
    @EnvironmentObject private var savedTemplatesStore: SavedTemplatesStore
    @EnvironmentObject private var likedTemplatesStore: LikedTemplatesStore

    let onClose: () -> Void

    @StateObject private var historyViewModel = ProfileHistoryViewModel()
    @State private var selectedSegment: ProfileSegment = DebugLaunchConfig.current.profileSegment ?? .posts
    @State private var selectedTaskForDetail: UserTask?

    private var visibleSegments: [ProfileSegment] {
        ProfileSegment.allCases.filter { $0 != .drafts }
    }

    var body: some View {
        ScreenContainer(showBrand: false, topSpacing: 18, bottomSpacing: 26) {
            GlamProTheme.background
        } content: {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    profileHeader
                    segmentedTabs
                    segmentContent
                }
                .padding(.horizontal, 15)
            }
            .refreshable {
                guard selectedSegment == .posts else { return }
                await historyViewModel.refresh(sessionManager: sessionManager)
            }
            .task(id: selectedSegment) {
                guard selectedSegment == .posts else { return }
                await historyViewModel.ensureLoaded(sessionManager: sessionManager)
            }
            .onAppear {
                if let segment = DebugLaunchConfig.current.profileSegment {
                    selectedSegment = segment == .drafts ? .posts : segment
                } else if selectedSegment == .drafts {
                    selectedSegment = .posts
                }
            }
            .fullScreenCover(item: $selectedTaskForDetail, onDismiss: {
                Task {
                    await historyViewModel.refresh(sessionManager: sessionManager, silently: true)
                }
            }) { task in
                ProfileTaskPreviewView(task: task)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            CircleIconButton(icon: "xmark", action: onClose)

            Spacer(minLength: 0)

            Text("Support")
                .font(.calm(15, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .frame(height: 34)
                .background(Capsule().fill(Color.white.opacity(0.09)))

            CircleIconButton(icon: "gift", action: {})
            CircleIconButton(icon: "gearshape.fill", action: {})
            CircleIconButton(icon: "bell", action: {})
        }
    }

    private var promoCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.22))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "arrow.down.doc.fill")
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Free Generations 🎉")
                    .font(.calm(17, weight: .bold))
                    .foregroundColor(.white)
                Text("Install the model to unlock this feature")
                    .font(.calm(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 68)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "C85B71"), Color(hex: "76234D")], startPoint: .leading, endPoint: .trailing))
        )
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 31))
                            .foregroundColor(.white.opacity(0.92))
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(sessionManager.displayUserName)
                        .font(.calm(20, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 26) {
                        statColumn(value: "0", title: "Following")
                        statColumn(value: "0", title: "Followers")
                        statColumn(value: "\(likedTemplatesStore.items.count)", title: "Likes")
                    }
                }
            }
        }
    }

    private var segmentedTabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(visibleSegments) { segment in
                    Button {
                        selectedSegment = segment
                    } label: {
                        VStack(spacing: 10) {
                            Text(segment.rawValue)
                                .font(.calm(16, weight: .bold))
                                .foregroundColor(selectedSegment == segment ? .white : .white.opacity(0.22))
                            Rectangle()
                                .fill(selectedSegment == segment ? Color.white : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(height: 1)
                .offset(y: -1)
        }
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case .drafts:
            historySection

        case .posts:
            historySection

        case .liked:
            likedSection

        case .saved:
            savedSection
        }
    }

    private var profileGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12, alignment: .top), count: 3)
    }

    private var likedSection: some View {
        Group {
            if likedTemplatesStore.items.isEmpty {
                ProfileLikedEmptyState()
                    .padding(.top, 12)
            } else {
                LazyVGrid(columns: profileGridColumns, spacing: 14) {
                    ForEach(likedTemplatesStore.items) { item in
                        ProfileLikedGridCard(
                            item: item,
                            onOpen: { openLikedItem(item) },
                            onRemove: { likedTemplatesStore.remove(id: item.id) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
            }
        }
    }

    private var savedSection: some View {
        Group {
            if savedTemplatesStore.items.isEmpty {
                ProfileSavedEmptyState(onTapExplore: navigateToHome)
            } else {
                LazyVGrid(columns: profileGridColumns, spacing: 14) {
                    ForEach(savedTemplatesStore.items) { item in
                        ProfileSavedGridCard(
                            item: item,
                            onOpen: { openSavedItem(item) },
                            onRemove: { savedTemplatesStore.remove(id: item.id) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
            }
        }
    }

    private var historySection: some View {
        VStack(spacing: 12) {
            if historyViewModel.isLoading && historyViewModel.tasks.isEmpty {
                LazyVGrid(columns: profileGridColumns, spacing: 14) {
                    ForEach(0..<6, id: \.self) { index in
                        ProfileHistorySkeletonCard(paletteIndex: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let errorMessage = historyViewModel.errorMessage, historyViewModel.tasks.isEmpty {
                ProfileHistoryMessageCard(
                    symbol: "exclamationmark.triangle.fill",
                    title: "Couldn’t load history",
                    message: errorMessage,
                    actionTitle: "Retry"
                ) {
                    Task {
                        await historyViewModel.refresh(sessionManager: sessionManager)
                    }
                }
            } else if historyViewModel.tasks.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Button(action: navigateToHome) {
                        ProfilePostsEmptyState()
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
            } else {
                LazyVGrid(columns: profileGridColumns, spacing: 14) {
                    ForEach(historyViewModel.tasks) { task in
                        ProfileHistoryGridCard(task: task) {
                            selectedTaskForDetail = task
                        }
                        .onAppear {
                            Task {
                                await historyViewModel.loadMoreIfNeeded(currentTask: task, sessionManager: sessionManager)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if historyViewModel.isLoadingMore {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading more...")
                            .font(.calm(14, weight: .medium))
                            .foregroundColor(GlamProTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else if let errorMessage = historyViewModel.errorMessage {
                    ProfileHistoryInlineError(message: errorMessage) {
                        Task {
                            await historyViewModel.loadMore(sessionManager: sessionManager)
                        }
                    }
                }
            }
        }
        .padding(.top, 18)
    }

    private func statColumn(value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.calm(17, weight: .bold))
                .foregroundColor(.white)
            Text(title)
                .font(.calm(12, weight: .medium))
                .foregroundColor(GlamProTheme.secondaryText)
        }
    }

    private func navigateToHome() {
        appState.goHome()
    }

    private func openSavedItem(_ item: SavedTemplateItem) {
        let previewItem = item.asRemoteFeatureItem
        appBootstrap.selectPreviewItem(previewItem)
        appState.open(.templatePreview)
    }

    private func openLikedItem(_ item: SavedTemplateItem) {
        let previewItem = item.asRemoteFeatureItem
        appBootstrap.selectPreviewItem(previewItem)
        appState.open(.templatePreview)
    }
}

private struct ProfileDraftsEmptyState: View {
    let onTapCreate: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Text("Your Drafts will\nbe stored here")
                .font(.calm(26, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 26)

            Button(action: onTapCreate) {
                Text("Create New")
                    .font(.calm(17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 166, height: 44)
                    .background(Capsule().fill(GlamProTheme.accentGradient))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}

private struct ProfilePostsEmptyState: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .frame(width: 100, height: 160)
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(Color.white))

                    Text("Creat New")
                        .font(.calm(16, weight: .bold))
                        .foregroundColor(.white)
                }
            )
            .padding(.top, 22)
    }
}

private struct ProfileLikedEmptyState: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.04 + Double(index) * 0.004))
                        .frame(height: 176)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.015), lineWidth: 0.8)
                        )
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                Text("Here will be displayed posts\nthat you like in the Feed")
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                    .multilineTextAlignment(.center)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.bottom, 2)
            }
        }
    }
}

private struct ProfileGridArtwork: View {
    private let cornerRadius: CGFloat = 16

    let url: URL?
    let paletteIndex: Int
    let isVideo: Bool
    let symbol: String?

    init(url: URL?, paletteIndex: Int, isVideo: Bool = false, symbol: String? = nil) {
        self.url = url
        self.paletteIndex = paletteIndex
        self.isVideo = isVideo
        self.symbol = symbol
    }

    var body: some View {
        ClippedArtworkContainer(cornerRadius: cornerRadius) {
            Group {
                if let url {
                    if isVideo {
                        ProfileVideoFirstFrameArtwork(url: url, paletteIndex: paletteIndex, cornerRadius: cornerRadius, symbol: symbol)
                    } else {
                        RemoteArtworkView(
                            url: url,
                            paletteIndex: paletteIndex,
                            cornerRadius: cornerRadius,
                            symbol: symbol,
                            contentMode: .fill
                        )
                    }
                } else {
                    PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: cornerRadius, symbol: symbol)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(100.0 / 160.0, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if isVideo {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.42)))
                    .padding(8)
            }
        }
    }
}

private struct ProfileVideoFirstFrameArtwork: View {
    let url: URL
    let paletteIndex: Int
    let cornerRadius: CGFloat
    let symbol: String?

    @State private var firstFrameImage: UIImage?

    var body: some View {
        Group {
            if let firstFrameImage {
                Image(uiImage: firstFrameImage)
                    .resizable()
                    .scaledToFill()
            } else {
                PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: cornerRadius, symbol: symbol)
            }
        }
        .task(id: url) {
            firstFrameImage = await ProfileVideoFrameExtractor.firstFrameImage(from: url)
        }
    }
}

private enum ProfileVideoFrameExtractor {
    static func firstFrameImage(from url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 720, height: 720)
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }.value
    }
}

private struct ProfileGridIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(10)
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileHistoryGridCard: View {
    let task: UserTask
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ProfileGridArtwork(
                url: task.canUseVideoFirstFrameInCard ? task.outputURL : (task.isVideoAsset ? nil : task.outputURL),
                paletteIndex: task.paletteIndex,
                isVideo: task.isVideoAsset,
                symbol: task.isVideoAsset ? "play.fill" : task.placeholderSymbol
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileHistorySkeletonCard: View {
    let paletteIndex: Int

    var body: some View {
        ClippedArtworkContainer(cornerRadius: 16) {
            PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: 16)
        }
        .aspectRatio(100.0 / 160.0, contentMode: .fit)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .opacity(0.55)
    }
}

private struct ProfileLikedGridCard: View {
    let item: SavedTemplateItem
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                ProfileGridArtwork(
                    url: item.effectiveCoverURL,
                    paletteIndex: item.paletteIndex,
                    isVideo: item.coverVideoURL != nil
                )
            }
            .buttonStyle(.plain)

            ProfileGridIconButton(icon: "heart.fill", action: onRemove)
                .padding(2)
        }
    }
}

private struct ProfileSavedGridCard: View {
    let item: SavedTemplateItem
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                ProfileGridArtwork(
                    url: item.effectiveCoverURL,
                    paletteIndex: item.paletteIndex,
                    isVideo: item.coverVideoURL != nil
                )
            }
            .buttonStyle(.plain)

            ProfileGridIconButton(icon: "bookmark.fill", action: onRemove)
                .padding(2)
        }
    }
}

private struct ProfileSavedEmptyState: View {
    let onTapExplore: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Styles you save\nwill be stored here")
                .font(.calm(18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Button(action: onTapExplore) {
                Text("Explore Styles")
                    .font(.calm(17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 158, height: 42)
                    .background(Capsule().fill(GlamProTheme.accentGradient))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 76)
    }
}

@MainActor
private final class ProfileHistoryViewModel: ObservableObject {
    @Published private(set) var tasks: [UserTask] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var total = 0
    @Published var errorMessage: String?

    private let apiClient: APIClient
    private let pageSize = 20
    private var didLoadOnce = false
    private var lastResponseCount = 0

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func ensureLoaded(sessionManager: SessionManager) async {
        guard !didLoadOnce || tasks.isEmpty else { return }
        await loadFirstPage(sessionManager: sessionManager, silently: false)
    }

    func refresh(sessionManager: SessionManager, silently: Bool = false) async {
        await loadFirstPage(sessionManager: sessionManager, silently: silently)
    }

    func loadMore(sessionManager: SessionManager) async {
        guard hasMore, !isLoading, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await fetchTasks(limit: pageSize, offset: tasks.count, sessionManager: sessionManager)
            lastResponseCount = response.tasks.count
            total = response.total ?? max(total, tasks.count + response.tasks.count)
            tasks = mergeTasks(existing: tasks, incoming: response.tasks)
            errorMessage = nil
            didLoadOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(currentTask: UserTask, sessionManager: SessionManager) async {
        guard shouldLoadMore(after: currentTask) else { return }
        await loadMore(sessionManager: sessionManager)
    }

    private var hasMore: Bool {
        if total > 0 {
            return tasks.count < total
        }
        return lastResponseCount == pageSize && !tasks.isEmpty
    }

    private func shouldLoadMore(after currentTask: UserTask) -> Bool {
        guard hasMore, let index = tasks.firstIndex(where: { $0.id == currentTask.id }) else { return false }
        return index >= max(tasks.count - 4, 0)
    }

    private func loadFirstPage(sessionManager: SessionManager, silently: Bool) async {
        guard !isLoading else { return }

        isLoading = true
        if !silently || tasks.isEmpty {
            errorMessage = nil
        }
        defer { isLoading = false }

        do {
            let response = try await fetchTasks(limit: pageSize, offset: 0, sessionManager: sessionManager)
            lastResponseCount = response.tasks.count
            total = response.total ?? response.tasks.count
            tasks = response.tasks
            errorMessage = nil
            didLoadOnce = true
        } catch {
            errorMessage = error.localizedDescription
            if tasks.isEmpty {
                total = 0
            }
        }
    }

    private func fetchTasks(limit: Int, offset: Int, sessionManager: SessionManager) async throws -> TaskListResponse {
        try await sessionManager.performAuthenticatedRequest { token in
            try await self.apiClient.get(
                path: "list-tasks",
                queryItems: [
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ],
                bearerToken: token
            )
        }
    }

    private func mergeTasks(existing: [UserTask], incoming: [UserTask]) -> [UserTask] {
        var seenIDs = Set(existing.map(\.id))
        var merged = existing

        for task in incoming where !seenIDs.contains(task.id) {
            merged.append(task)
            seenIDs.insert(task.id)
        }

        return merged
    }
}

private struct ProfileTaskRow: View {
    let task: UserTask

    var body: some View {
        HStack(spacing: 12) {
            ProfileTaskThumbnail(task: task)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text(task.sceneDisplayName)
                        .font(.calm(18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    ProfileTaskStatusBadge(task: task)
                }

                Text(task.createdAtDisplayText)
                    .font(.calm(13, weight: .medium))
                    .foregroundColor(GlamProTheme.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let creditsText = task.creditsUsedDisplayText {
                        ProfileTaskMetaChip(icon: "bolt.fill", title: creditsText, tint: GlamProTheme.yellow)
                    }

                    if let menuText = task.sectionMenuDisplayText {
                        ProfileTaskMetaChip(icon: "square.grid.2x2.fill", title: menuText, tint: GlamProTheme.blue)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: task.isVideoAsset ? "play.circle.fill" : "photo.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.74))
                    Text(task.outputURL == nil ? "Tap to check status" : "Tap to preview")
                        .font(.calm(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.74))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct ProfileTaskThumbnail: View {
    let task: UserTask

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let outputURL = task.outputURL, !task.isVideoAsset {
                    GlamCachedAsyncImage(url: outputURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        PlaceholderArtwork(paletteIndex: task.paletteIndex, cornerRadius: 18, symbol: task.placeholderSymbol)
                    }
                } else {
                    PlaceholderArtwork(paletteIndex: task.paletteIndex, cornerRadius: 18, symbol: task.placeholderSymbol)
                }
            }
            .frame(width: 96, height: 126)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if task.isVideoAsset {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.black.opacity(0.42)))
                    .padding(10)
            }
        }
    }
}

private struct ProfileTaskStatusBadge: View {
    let task: UserTask

    var body: some View {
        Text(task.statusDisplayText)
            .font(.calm(12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(task.statusColor.opacity(0.92)))
    }
}

private struct ProfileTaskMetaChip: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .lineLimit(1)
        }
        .font(.calm(12, weight: .bold))
        .foregroundColor(.white.opacity(0.84))
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule()
                .fill(tint.opacity(0.18))
                .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 0.8))
        )
    }
}

private struct ProfileHistorySkeletonRow: View {
    let paletteIndex: Int

    var body: some View {
        HStack(spacing: 12) {
            PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: 18)
                .frame(width: 96, height: 126)

            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 140, height: 18)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 110, height: 14)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 90, height: 26)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 130, height: 26)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

private struct ProfileHistoryMessageCard: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color.white.opacity(0.1)))

            Text(title)
                .font(.calm(22, weight: .bold))
                .foregroundColor(.white)

            Text(message)
                .font(.calm(15, weight: .medium))
                .foregroundColor(GlamProTheme.secondaryText)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.calm(16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 42)
                        .background(Capsule().fill(GlamProTheme.accentGradient))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct ProfileHistoryInlineError: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(GlamProTheme.orange)
            Text(message)
                .font(.calm(13, weight: .medium))
                .foregroundColor(GlamProTheme.secondaryText)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button("Retry", action: retry)
                .font(.calm(13, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private struct ProfileTaskPreviewView: View {
    private struct SaveFeedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let opensSettings: Bool
    }

    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let task: UserTask

    @StateObject private var viewModel: ProfileTaskPreviewViewModel
    @State private var isVideoPaused = false
    @State private var isSaving = false
    @State private var saveFeedback: SaveFeedback?

    init(task: UserTask) {
        self.task = task
        _viewModel = StateObject(wrappedValue: ProfileTaskPreviewViewModel(task: task))
    }

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom

            ZStack {
                Color.clear

                if viewModel.isResolving {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text(viewModel.statusDetailText)
                            .font(.calm(15, weight: .bold))
                            .foregroundColor(.white)
                        Text("This task is still being processed.")
                            .font(.calm(13, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black.opacity(0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background {
                previewContent
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .overlay(alignment: .bottom) {
                bottomPanel(bottomInset: safeBottom)
                    .frame(width: geometry.size.width, alignment: .center)
                    .offset(y: 30)
            }
            .overlay(alignment: .topLeading) {
                topBar(topInset: safeTop)
                    .zIndex(20)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .clipped()
            .background(Color.black.ignoresSafeArea())
            .ignoresSafeArea()
        }
        .task {
            await viewModel.ensureResolved(sessionManager: sessionManager)
        }
        .alert(item: $saveFeedback) { feedback in
            if feedback.opensSettings {
                return Alert(
                    title: Text(feedback.title),
                    message: Text(feedback.message),
                    primaryButton: .default(Text("Settings"), action: openAppSettings),
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }

            return Alert(
                title: Text(feedback.title),
                message: Text(feedback.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if let mediaURL = viewModel.mediaURL {
            if viewModel.isVideoAsset {
                ProfileLoopingVideoView(url: mediaURL, isPaused: isVideoPaused)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isVideoPaused.toggle()
                    }
            } else {
                ZStack {
                    GlamCachedAsyncImage(url: mediaURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 24)
                            .overlay(Color.black.opacity(0.18))
                    } placeholder: {
                        PlaceholderArtwork(paletteIndex: task.paletteIndex, cornerRadius: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    GlamCachedAsyncImage(url: mediaURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        PlaceholderArtwork(paletteIndex: task.paletteIndex, cornerRadius: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
            }
        } else if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 14) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(GlamProTheme.orange)

                Text(viewModel.statusDetailText)
                    .font(.calm(22, weight: .bold))
                    .foregroundColor(.white)

                Text(errorMessage)
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(GlamProTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        } else {
            PlaceholderArtwork(paletteIndex: task.paletteIndex, cornerRadius: 0, symbol: task.placeholderSymbol)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
    }

    private func topBar(topInset: CGFloat) -> some View {
        let resolvedTopInset = max(topInset, 10)
        return HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.26), lineWidth: 0.9)
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, resolvedTopInset + 8)
    }

    private func bottomPanel(bottomInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.sceneDisplayName)
                        .font(.calm(18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(viewModel.statusDetailText)
                        .font(.calm(14, weight: .medium))
                        .foregroundColor(GlamProTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)
            }

            Button(action: saveResult) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isSaving ? "Saving..." : "Save")
                        .font(.calm(16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(viewModel.mediaURL == nil ? AnyShapeStyle(Color.white.opacity(0.08)) : AnyShapeStyle(GlamProTheme.accentGradient))
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.mediaURL == nil || isSaving)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, max(bottomInset, 8))
        .background(Color.black)
    }

    private func saveResult() {
        guard !isSaving else { return }
        Task {
            await saveResultToPhotoLibrary()
        }
    }

    @MainActor
    private func saveResultToPhotoLibrary() async {
        guard let mediaURL = viewModel.mediaURL else {
            saveFeedback = SaveFeedback(title: "Save Failed", message: "No generated result is available yet.", opensSettings: false)
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let status = await ProfileMediaSaver.requestPhotoLibraryAddPermission()
            guard ProfileMediaSaver.isPhotoLibraryAccessGranted(status) else {
                saveFeedback = SaveFeedback(
                    title: "Photos Access Needed",
                    message: "Please allow photo access so Glam Pro can save generated content to your Photos.",
                    opensSettings: status == .denied || status == .restricted
                )
                return
            }

            if viewModel.isVideoAsset {
                try await ProfileMediaSaver.saveVideoToPhotoLibrary(from: mediaURL)
                saveFeedback = SaveFeedback(title: "Saved", message: "Your video has been saved to Photos.", opensSettings: false)
            } else {
                try await ProfileMediaSaver.saveImageToPhotoLibrary(from: mediaURL)
                saveFeedback = SaveFeedback(title: "Saved", message: "Your image has been saved to Photos.", opensSettings: false)
            }
        } catch {
            saveFeedback = SaveFeedback(title: "Save Failed", message: error.localizedDescription, opensSettings: false)
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

@MainActor
private final class ProfileTaskPreviewViewModel: ObservableObject {
    @Published private(set) var status: String
    @Published private(set) var mediaURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isResolving = false

    let task: UserTask

    private let apiClient: APIClient
    private var hasStarted = false

    init(task: UserTask, apiClient: APIClient = .shared) {
        self.task = task
        self.apiClient = apiClient
        self.status = task.normalizedStatus
        self.mediaURL = task.outputURL
    }

    var isVideoAsset: Bool {
        task.isVideoAsset || mediaURL?.pathExtension.lowercased().isVideoPathExtension == true
    }

    var statusDetailText: String {
        switch status {
        case "completed", "done", "success":
            return mediaURL == nil ? "Result pending" : "Result ready"
        case "failed", "error":
            return "Generation failed"
        case "queued", "pending":
            return "Queued"
        default:
            return "Processing"
        }
    }

    func ensureResolved(sessionManager: SessionManager) async {
        guard !hasStarted else { return }
        hasStarted = true

        guard mediaURL == nil || !isTerminalStatus else {
            return
        }

        isResolving = true
        defer { isResolving = false }

        do {
            while !Task.isCancelled {
                let response: GenerationTaskStatusResponse = try await sessionManager.performAuthenticatedRequest { token in
                    try await self.apiClient.get(
                        path: "get-task",
                        queryItems: [URLQueryItem(name: "task_id", value: self.task.id)],
                        bearerToken: token
                    )
                }

                let latestStatus = response.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? status
                status = latestStatus
                mediaURL = response.outputURL ?? mediaURL

                if ["completed", "done", "success"].contains(latestStatus) {
                    if mediaURL == nil {
                        errorMessage = "The generated result is not available yet. Please try again later."
                    }
                    return
                }

                if ["failed", "error"].contains(latestStatus) {
                    errorMessage = response.resolvedErrorMessage
                    return
                }

                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var isTerminalStatus: Bool {
        ["completed", "done", "success", "failed", "error"].contains(status)
    }
}

private enum ProfileMediaSaver {
    static func requestPhotoLibraryAddPermission() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if currentStatus == .notDetermined {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
        }
        return currentStatus
    }

    static func isPhotoLibraryAccessGranted(_ status: PHAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    static func saveImageToPhotoLibrary(from remoteURL: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: remoteURL)
        guard let image = UIImage(data: data) else {
            throw ProfileMediaSaveError.invalidImageData
        }

        try await performPhotoLibraryChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    static func saveVideoToPhotoLibrary(from remoteURL: URL) async throws {
        let (downloadURL, _) = try await URLSession.shared.download(from: remoteURL)
        let fileManager = FileManager.default
        let fileExtension = remoteURL.pathExtension.isEmpty ? "mp4" : remoteURL.pathExtension
        let targetURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        if fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }

        try fileManager.copyItem(at: downloadURL, to: targetURL)
        defer { try? fileManager.removeItem(at: targetURL) }

        try await performPhotoLibraryChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: targetURL)
        }
    }

    private static func performPhotoLibraryChanges(_ changes: @escaping () -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges(changes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: ProfileMediaSaveError.saveFailed)
                }
            }
        }
    }
}

private enum ProfileMediaSaveError: LocalizedError {
    case invalidImageData
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The generated image could not be prepared for saving."
        case .saveFailed:
            return "Saving to Photos failed. Please try again."
        }
    }
}

private struct ProfileLoopingVideoView: View {
    let url: URL
    let isPaused: Bool

    @StateObject private var playerEngine = ProfileVideoEngine()

    var body: some View {
        ProfilePlayerView(player: playerEngine.player)
            .onAppear {
                playerEngine.configure(url: url)
                syncPlayback()
            }
            .task(id: url) {
                playerEngine.configure(url: url)
                syncPlayback()
            }
            .onChange(of: isPaused) { _ in
                syncPlayback()
            }
            .onDisappear {
                playerEngine.pause()
            }
    }

    private func syncPlayback() {
        if isPaused {
            playerEngine.pause()
        } else {
            playerEngine.play()
        }
    }
}

private final class ProfileVideoEngine: ObservableObject {
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?
    private var currentURL: URL?
    private var loadTask: Task<Void, Never>?

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .none
    }

    func configure(url: URL) {
        guard currentURL != url else { return }
        currentURL = url
        player.pause()
        player.removeAllItems()
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let playableURL = await GlamVideoCacheManager.shared.cachedURL(for: url)
            guard !Task.isCancelled, self.currentURL == url else { return }
            let item = AVPlayerItem(url: playableURL)
            self.looper = AVPlayerLooper(player: self.player, templateItem: item)
        }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }
}

private struct ProfilePlayerView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> ProfilePlayerContainerView {
        let view = ProfilePlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: ProfilePlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspectFill
    }
}

private final class ProfilePlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private extension UserTask {
    var outputURL: URL? {
        guard let outputURLString, !outputURLString.isEmpty else { return nil }
        return URL(string: outputURLString)
    }

    var normalizedStatus: String {
        status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "processing"
    }

    var statusDisplayText: String {
        switch normalizedStatus {
        case "completed", "done", "success":
            return "Completed"
        case "failed", "error":
            return "Failed"
        case "queued", "pending":
            return "Pending"
        default:
            return "Processing"
        }
    }

    var statusColor: Color {
        switch normalizedStatus {
        case "completed", "done", "success":
            return GlamProTheme.blue
        case "failed", "error":
            return GlamProTheme.orange
        case "queued", "pending":
            return GlamProTheme.indigo
        default:
            return GlamProTheme.purple
        }
    }

    var sceneDisplayName: String {
        let trimmed = scene?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "AI Creation" }
        return trimmed
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    var createdAtDisplayText: String {
        guard let createdAt, let date = ProfileDateParser.parse(createdAt) else {
            return "Just now"
        }
        return ProfileDateParser.displayFormatter.string(from: date)
    }

    var creditsUsedDisplayText: String? {
        guard let creditsUsed, creditsUsed > 0 else { return nil }
        return "\(creditsUsed) credits"
    }

    var sectionMenuDisplayText: String? {
        let trimmed = sectionMenu?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var isVideoAsset: Bool {
        if let outputURL, outputURL.pathExtension.lowercased().isVideoPathExtension {
            return true
        }
        return ["image_to_video", "text_to_video", "video_face_swap"].contains(scene?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "")
    }

    var isSuccessStatus: Bool {
        ["completed", "done", "success"].contains(normalizedStatus)
    }

    var canUseVideoFirstFrameInCard: Bool {
        isVideoAsset && isSuccessStatus && outputURL != nil
    }

    var placeholderSymbol: String {
        isVideoAsset ? "play.fill" : "photo.fill"
    }

    var paletteIndex: Int {
        abs(id.hashValue) % 8
    }
}

private enum ProfileDateParser {
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    private static let isoFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        return [withFractional, standard]
    }()

    static func parse(_ value: String) -> Date? {
        for formatter in isoFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)
    }
}

private extension String {
    var isVideoPathExtension: Bool {
        ["mp4", "mov", "m4v", "avi", "webm"].contains(lowercased())
    }
}
