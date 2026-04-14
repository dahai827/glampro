import SwiftUI
import AVFoundation
import UIKit
import CryptoKit

enum GlamMediaCacheBootstrap {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        URLCache.shared = URLCache(
            memoryCapacity: 80 * 1024 * 1024,
            diskCapacity: 700 * 1024 * 1024,
            directory: nil
        )
    }
}

struct GlamCachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader = GlamCachedImageLoader()

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage = loader.image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loader.load(url: url)
        }
    }
}

@MainActor
private final class GlamCachedImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var currentURL: URL?

    func load(url: URL?) async {
        guard currentURL != url else { return }
        currentURL = url
        image = nil
        guard let url else { return }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let cachedImage = UIImage(data: cached.data) {
            image = cachedImage
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return
            }
            if let resolvedImage = UIImage(data: data) {
                image = resolvedImage
                URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            }
        } catch {
            return
        }
    }
}

actor GlamVideoCacheManager {
    static let shared = GlamVideoCacheManager()

    private var inFlightTasks: [String: Task<Void, Never>] = [:]
    private let fileManager = FileManager.default

    private lazy var cacheDirectory: URL = {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("GlamVideoCache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    func cachedURL(for remoteURL: URL) async -> URL {
        let key = remoteURL.absoluteString
        let localURL = localFileURL(for: remoteURL)
        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }

        // Keep playback responsive: play remote URL immediately, cache in background for next time.
        if inFlightTasks[key] == nil {
            inFlightTasks[key] = Task { [weak self] in
                guard let self else { return }
                await self.cacheRemoteVideo(remoteURL, to: localURL, key: key)
            }
        }

        return remoteURL
    }

    private func cacheRemoteVideo(_ remoteURL: URL, to localURL: URL, key: String) async {
        defer { inFlightTasks.removeValue(forKey: key) }
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return
            }
            if fileManager.fileExists(atPath: localURL.path) {
                try? fileManager.removeItem(at: localURL)
            }
            try? fileManager.moveItem(at: tempURL, to: localURL)
        } catch {
            return
        }
    }

    private func localFileURL(for remoteURL: URL) -> URL {
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
        let ext = remoteURL.pathExtension.isEmpty ? "mp4" : remoteURL.pathExtension
        return cacheDirectory.appendingPathComponent("\(digest).\(ext)")
    }
}

struct ScreenContainer<Content: View>: View {
    let background: AnyView
    let showBrand: Bool
    let topSpacing: CGFloat
    let bottomSpacing: CGFloat
    private let content: Content

    init<Background: View>(showBrand: Bool = true, topSpacing: CGFloat? = nil, bottomSpacing: CGFloat = 98, @ViewBuilder background: () -> Background, @ViewBuilder content: () -> Content) {
        self.background = AnyView(background())
        self.showBrand = showBrand
        self.topSpacing = topSpacing ?? (showBrand ? 54 : 0)
        self.bottomSpacing = bottomSpacing
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            background
                .ignoresSafeArea()

            content
                .padding(.top, topSpacing)
                .padding(.bottom, bottomSpacing)

            if showBrand {
                BrandPill()
                    .padding(.top, 9)
            }
        }
    }
}

struct BrandPill: View {
    var body: some View {
        HStack(spacing: 7) {
            BrandOrb(size: 18)
            Text("Glam Pro")
                .font(.calm(15, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "AF745D").opacity(0.82))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )
    }
}

struct BrandOrb: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(GlamProTheme.brandGradient)
            Circle()
                .fill(Color.black.opacity(0.2))
                .frame(width: size * 0.64, height: size * 0.64)
            Circle()
                .fill(Color.black)
                .frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}

struct CircleIconButton: View {
    let icon: String
    let size: CGFloat
    let iconColor: Color
    let backgroundColor: Color
    let borderColor: Color
    let action: () -> Void

    init(
        icon: String,
        size: CGFloat = 34,
        iconColor: Color = .white,
        backgroundColor: Color = Color.white.opacity(0.1),
        borderColor: Color = Color.white.opacity(0.05),
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CapsuleChip: View {
    let title: String
    var systemImage: String?
    var badgeText: String?
    var isSelected = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
            }

            Text(title)
                .font(.calm(16, weight: .bold))

            if let badgeText {
                Text(badgeText)
                    .font(.calm(13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .frame(height: 25)
                    .background(Capsule().fill(GlamProTheme.pink))
            }
        }
        .foregroundColor(isSelected ? .black : .white.opacity(0.94))
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(
            Capsule()
                .fill(isSelected ? Color.white : Color.white.opacity(0.09))
        )
    }
}

struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.calm(21, weight: .heavy))
                .foregroundColor(.white)

            Spacer()

            if let actionTitle {
                Button(action: { action?() }) {
                    HStack(spacing: 5) {
                        Text(actionTitle)
                            .font(.calm(15, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 33)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PlaceholderArtwork: View {
    let paletteIndex: Int
    var cornerRadius: CGFloat = 20
    var symbol: String? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(GlamProTheme.cardGradient(paletteIndex))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear, Color.black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 130, height: 130)
                .blur(radius: 22)
                .offset(x: -44, y: -32)

            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 180, height: 180)
                .blur(radius: 24)
                .offset(x: 64, y: 76)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}



struct ClippedArtworkContainer<Content: View>: View {
    let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .clipped()
    }
}

struct RemoteArtworkView: View {
    let url: URL?
    let paletteIndex: Int
    let cornerRadius: CGFloat
    var symbol: String? = nil
    var contentMode: ContentMode = .fill

    var body: some View {
        ZStack {
            PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: cornerRadius, symbol: symbol)

            if let url {
                GlamCachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } placeholder: {
                    Color.clear
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct RemoteLoopingVideoArtworkView: View {
    let videoURL: URL
    let fallbackImageURL: URL?
    let paletteIndex: Int
    let cornerRadius: CGFloat

    @StateObject private var engine = RemoteLoopingVideoEngine()

    var body: some View {
        ZStack {
            PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: cornerRadius)

            if let fallbackImageURL {
                GlamCachedAsyncImage(url: fallbackImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } placeholder: {
                    Color.clear
                }
            }

            RemoteLoopingVideoPlayerView(player: engine.player)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            engine.configure(url: videoURL)
            engine.play()
        }
        .task(id: videoURL) {
            engine.configure(url: videoURL)
            engine.play()
        }
        .onDisappear {
            engine.pause()
        }
    }
}

private final class RemoteLoopingVideoEngine: ObservableObject {
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?
    private var currentURL: URL?
    private var loadTask: Task<Void, Never>?
    private var shouldAutoPlay = false

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
            if self.shouldAutoPlay {
                self.player.play()
            }
        }
    }

    func play() {
        shouldAutoPlay = true
        player.play()
    }

    func pause() {
        shouldAutoPlay = false
        player.pause()
    }
}

private struct RemoteLoopingVideoPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> RemoteLoopingVideoPlayerContainerView {
        let view = RemoteLoopingVideoPlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: RemoteLoopingVideoPlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspectFill
    }
}

private final class RemoteLoopingVideoPlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

struct GradientButton: View {
    let title: String
    let subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(.calm(17, weight: .bold))
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.calm(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.94))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(GlamProTheme.accentGradient)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProgressRing: View {
    let progress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(GlamProTheme.purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.calm(28, weight: .bold))
                    .foregroundColor(GlamProTheme.purple)
                Text("RENDERING")
                    .font(.calm(10, weight: .bold))
                    .kerning(1)
                    .foregroundColor(.white.opacity(0.56))
            }
        }
    }
}
