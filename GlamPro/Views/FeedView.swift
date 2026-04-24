import SwiftUI
import UIKit

struct FeedView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appBootstrap: AppBootstrapStore

    let openProfile: () -> Void
    let openPreview: () -> Void

    var body: some View {
        ScreenContainer(showBrand: false, topSpacing: 18, bottomSpacing: 84) {
            GlamProTheme.background
        } content: {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    feedGrid
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("Popular")
                        .font(.calm(16, weight: .heavy))
                        .foregroundColor(.white)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 24, height: 2.5)
                    }
                }

            Spacer(minLength: 0)

            if !appBootstrap.isReviewVersion {
                CircleIconButton(icon: "person.fill", action: openProfile)
            }
        }
    }

    private var feedGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(feedItems) { item in
                feedCard(item)
            }
        }
        .padding(.bottom, 100)
    }

    private func feedCard(_ item: RemoteFeatureItem) -> some View {
        return ZStack(alignment: .topTrailing) {
            Button {
                if item.isAd, let adURL = item.adIOSURL {
                    openURL(adURL)
                    return
                }
                appBootstrap.selectPreviewItem(item)
                openPreview()
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    feedArtwork(item)
                        .overlay(alignment: .bottomLeading) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.22))
                                    .frame(width: 28, height: 28)
                                HStack(spacing: 1) {
                                    Image(systemName: item.isAd ? "link" : "wand.and.stars")
                                        .font(.system(size: 9, weight: .bold))
                                    Image(systemName: "plus")
                                        .font(.system(size: 7, weight: .heavy))
                                }
                                .foregroundColor(.white)
                            }
                            .padding(8)
                        }

                    Text(item.title)
                        .font(.calm(14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
            }
            .buttonStyle(.plain)

            if !item.isAd {
                SavedTemplateBookmarkButton(item: item, iconSize: 14, padding: 10)
            }
        }
    }

    @ViewBuilder
    private func feedArtwork(_ item: RemoteFeatureItem) -> some View {
        if let urls = beforeAfterURLs(for: item) {
            FeedBeforeAfterAutoView(
                beforeURL: urls.before,
                afterURL: urls.after,
                fallbackURL: item.effectiveCoverURL,
                paletteIndex: paletteIndex(for: item.id),
                cornerRadius: 16
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
        } else {
            ClippedArtworkContainer(cornerRadius: 16) {
                RemoteArtworkView(
                    url: item.effectiveCoverURL,
                    paletteIndex: paletteIndex(for: item.id),
                    cornerRadius: 16,
                    contentMode: .fill
                )
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
        }
    }

    private func beforeAfterURLs(for item: RemoteFeatureItem) -> (before: URL, after: URL)? {
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

    private var feedItems: [RemoteFeatureItem] {
        let imageSections = appBootstrap.imageSections.filter { section in
            let menu = section.menu?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            return menu.isEmpty || menu == "image"
        }

        return imageSections
            .sorted { ($0.sortOrder ?? .max, $0.displayTitle) < ($1.sortOrder ?? .max, $1.displayTitle) }
            .flatMap { section in
                section.items.sorted { ($0.sortOrder ?? .max, $0.title) < ($1.sortOrder ?? .max, $1.title) }
            }
            .filter { item in
                let normalizedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let normalizedKey = normalizedTitle.replacingOccurrences(of: " ", with: "")
                return normalizedTitle != "create"
                    && normalizedTitle != "edit"
                    && normalizedTitle != "motion swap"
                    && normalizedKey != "motionswap"
            }
    }

    private func paletteIndex(for id: String) -> Int {
        abs(id.hashValue) % 8
    }
}

private struct FeedBeforeAfterAutoView: View {
    let beforeURL: URL
    let afterURL: URL
    let fallbackURL: URL?
    let paletteIndex: Int
    let cornerRadius: CGFloat

    @StateObject private var loader = FeedBeforeAfterImageLoader()
    @State private var currentIndex = 0
    @State private var slideOffset: CGFloat = 0

    var body: some View {
        Group {
            if let beforeImage = loader.beforeImage, let afterImage = loader.afterImage {
                sliderContent(beforeImage: beforeImage, afterImage: afterImage)
            } else {
                ClippedArtworkContainer(cornerRadius: cornerRadius) {
                    RemoteArtworkView(
                        url: fallbackURL ?? beforeURL,
                        paletteIndex: paletteIndex,
                        cornerRadius: cornerRadius,
                        contentMode: .fill
                    )
                }
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
private final class FeedBeforeAfterImageLoader: ObservableObject {
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
