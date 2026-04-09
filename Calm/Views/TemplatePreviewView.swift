import SwiftUI
import AVFoundation
import UIKit

struct TemplatePreviewView: View {
    @EnvironmentObject private var appBootstrap: AppBootstrapStore
    @EnvironmentObject private var previewGenerationStore: PreviewGenerationStore
    @EnvironmentObject private var savedTemplatesStore: SavedTemplatesStore
    @EnvironmentObject private var likedTemplatesStore: LikedTemplatesStore
    @State private var isMediaPaused = false

    let onClose: () -> Void
    let onCreate: () -> Void

    private let horizontalPadding: CGFloat = 16
    private let overlayHorizontalPadding: CGFloat = 16

    private var selectedItem: RemoteFeatureItem? {
        appBootstrap.selectedPreviewItem
    }

    private var paletteIndex: Int {
        abs((selectedItem?.id ?? "preview").hashValue) % 8
    }

    private var previewTitle: String? {
        let primary = selectedItem?.previewConfig?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let primary, !primary.isEmpty {
            return primary
        }

        let fallback = selectedItem?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (fallback?.isEmpty == false) ? fallback : nil
    }

    private var previewDescription: String? {
        let primary = selectedItem?.previewConfig?.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let primary, !primary.isEmpty {
            return primary
        }

        let fallback = selectedItem?.displaySubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return (fallback?.isEmpty == false) ? fallback : nil
    }

    private var hasVideo: Bool {
        selectedItem?.coverVideoURL != nil
    }

    private var windowSafeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\ .windows)
            .first(where: \ .isKeyWindow)?
            .safeAreaInsets ?? .zero
    }

    var body: some View {
        GeometryReader { geometry in
            let safeTop = max(geometry.safeAreaInsets.top, windowSafeAreaInsets.top)
            let safeBottom = max(geometry.safeAreaInsets.bottom, windowSafeAreaInsets.bottom)
            let titleBottomInset = max(safeBottom + 112, 120)
            let actionBottomInset = max(safeBottom + 116, 124)

            ZStack {
                Color.clear

                previewTextLayer(availableWidth: geometry.size.width)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 18)
                    .padding(.bottom, titleBottomInset)

                actionColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 18)
                    .padding(.bottom, actionBottomInset)

                createButtonLayer(bottomInset: max(safeBottom, 8) + 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .background {
                TemplatePreviewMediaBackground(
                    item: selectedItem,
                    paletteIndex: paletteIndex,
                    isPaused: isMediaPaused,
                    onTapMedia: toggleMediaPlayback
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .overlay(alignment: .topLeading) {
                backButton
                    .padding(.leading, overlayHorizontalPadding)
                    .padding(.top, safeTop + 8)
                    .zIndex(10)
            }
        }
        .ignoresSafeArea()
        .task(id: selectedItem?.id) {
            isMediaPaused = false
            previewGenerationStore.syncPreviewItem(selectedItem)
        }
    }

    @ViewBuilder
    private func previewTextLayer(availableWidth: CGFloat) -> some View {
        if previewTitle != nil || previewDescription != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let previewTitle {
                    Text(previewTitle)
                        .font(.calm(28, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if let previewDescription {
                    Text(previewDescription)
                        .font(.calm(15, weight: .medium))
                        .foregroundColor(.white.opacity(0.86))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: min(availableWidth - 112, 262), alignment: .leading)
        }
    }

    private var actionColumn: some View {
        VStack(alignment: .center, spacing: 24) {
            likeActionItem
            bookmarkActionItem
            actionItem(icon: "arrowshape.turn.up.right", title: "Share")
        }
    }

    private func createButtonLayer(bottomInset: CGFloat) -> some View {
        VStack(spacing: 8) {
            Button(action: onCreate) {
                HStack(spacing: 8) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 14, weight: .bold))
                    Text(actionTitle)
                        .font(.calm(18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(CalmTheme.accentGradient)
                )
            }
            .buttonStyle(.plain)

            Text(selectedItem?.creditsText ?? "50 Coins")
                .font(.calm(14, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomInset)
    }

    private var backButton: some View {
        Button(action: onClose) {
            Image(systemName: "chevron.left")
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.black.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func toggleMediaPlayback() {
        guard hasVideo else { return }
        isMediaPaused.toggle()
    }

    private var actionTitle: String {
        if selectedItem?.materialRequirements.contains(where: { $0.type == "single_image" || $0.type == "multiple_images" }) == true {
            return "Photo"
        }
        return "Create"
    }

    private var actionIcon: String {
        actionTitle == "Photo" ? "camera.fill" : "sparkles"
    }

    @ViewBuilder
    private var likeActionItem: some View {
        if let selectedItem {
            Button {
                likedTemplatesStore.toggle(selectedItem)
            } label: {
                VStack(spacing: 7) {
                    Image(systemName: likedTemplatesStore.isLiked(selectedItem) ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)

                    Text(likedTemplatesStore.isLiked(selectedItem) ? "Liked" : "Like")
                        .font(.calm(14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 64)
                }
            }
            .buttonStyle(.plain)
        } else {
            actionItem(icon: "heart", title: "Like")
        }
    }

    @ViewBuilder
    private var bookmarkActionItem: some View {
        if let selectedItem {
            Button {
                savedTemplatesStore.toggle(selectedItem)
            } label: {
                VStack(spacing: 7) {
                    Image(systemName: savedTemplatesStore.isSaved(selectedItem) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)

                    Text(savedTemplatesStore.isSaved(selectedItem) ? "Saved" : "Save")
                        .font(.calm(14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 64)
                }
            }
            .buttonStyle(.plain)
        } else {
            actionItem(icon: "bookmark", title: "Save")
        }
    }

    private func actionItem(icon: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)

            Text(title)
                .font(.calm(14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 64)
        }
    }
}

private struct TemplatePreviewMediaBackground: View {
    let item: RemoteFeatureItem?
    let paletteIndex: Int
    let isPaused: Bool
    let onTapMedia: () -> Void

    var body: some View {
        ZStack {
            Color.black

            RemoteArtworkView(
                url: item?.effectiveCoverURL,
                paletteIndex: paletteIndex,
                cornerRadius: 0,
                contentMode: .fill
            )

            if let videoURL = item?.coverVideoURL {
                TemplatePreviewLoopingVideoView(url: videoURL, isPaused: isPaused)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.26), Color.clear],
                startPoint: .top,
                endPoint: .center
            )

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.18), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapMedia)
    }
}

private struct TemplatePreviewLoopingVideoView: View {
    let url: URL
    let isPaused: Bool

    @StateObject private var playerEngine = TemplatePreviewVideoEngine()

    var body: some View {
        TemplatePreviewPlayerView(player: playerEngine.player)
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

private final class TemplatePreviewVideoEngine: ObservableObject {
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .none
    }

    func configure(url: URL) {
        guard currentURL != url else { return }

        currentURL = url
        player.pause()
        player.removeAllItems()

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    deinit {
        pause()
        player.removeAllItems()
        looper = nil
    }
}

private struct TemplatePreviewPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> TemplatePreviewPlayerContainerView {
        let view = TemplatePreviewPlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: TemplatePreviewPlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspectFill
    }
}

private final class TemplatePreviewPlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
