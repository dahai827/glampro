import SwiftUI
import AVFoundation
import Photos
import UIKit

struct GenerationResultView: View {
    private struct SaveFeedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let opensSettings: Bool
    }

    @EnvironmentObject private var previewGenerationStore: PreviewGenerationStore
    @Environment(\.openURL) private var openURL

    let onClose: () -> Void
    let onGoToProfile: () -> Void

    @State private var isVideoPaused = false
    @State private var isSavingResult = false
    @State private var saveFeedback: SaveFeedback?

    private var result: PreviewGenerationStore.GeneratedResult? {
        previewGenerationStore.result
    }

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                previewStage(topInset: safeTop)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                bottomPanel(bottomInset: safeBottom)
                    .offset(y: 30)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(CalmTheme.background.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
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

    private func previewStage(topInset: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            resultBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            topBar(topInset: topInset)
        }
        .background(Color.black)
    }

    @ViewBuilder
    private var resultBackground: some View {
        if let result {
            if result.isVideo {
                ResultLoopingVideoView(url: result.url, isPaused: isVideoPaused)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isVideoPaused.toggle()
                    }
            } else {
                ZStack {
                    AsyncImage(url: result.url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 24)
                                .overlay(Color.black.opacity(0.18))
                        default:
                            PlaceholderArtwork(paletteIndex: 0, cornerRadius: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    AsyncImage(url: result.url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            PlaceholderArtwork(paletteIndex: 0, cornerRadius: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
            }
        } else {
            PlaceholderArtwork(paletteIndex: 0, cornerRadius: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
    }

    private func topBar(topInset: CGFloat) -> some View {
        HStack {
            CircleIconButton(icon: "chevron.left", size: 40, action: onClose)
            Spacer(minLength: 0)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.top, topInset + 8)
    }

    private func bottomPanel(bottomInset: CGFloat) -> some View {
        HStack(spacing: 12) {
            actionButton(
                title: "Go To Profile",
                icon: "person.crop.circle",
                fill: AnyShapeStyle(Color.white.opacity(0.12)),
                foreground: .white,
                action: onGoToProfile
            )

            actionButton(
                title: isSavingResult ? "Saving..." : "Save",
                icon: "square.and.arrow.down",
                fill: AnyShapeStyle(CalmTheme.accentGradient),
                foreground: .white,
                isLoading: isSavingResult,
                action: saveAction
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, max(bottomInset, 12) + 6)
        .background(CalmTheme.background)
    }

    private func saveAction() {
        guard !isSavingResult else { return }
        Task {
            await saveResultToPhotoLibrary()
        }
    }

    @MainActor
    private func saveResultToPhotoLibrary() async {
        guard let result else {
            saveFeedback = SaveFeedback(title: "Save Failed", message: "No generated result is available yet.", opensSettings: false)
            return
        }

        isSavingResult = true
        defer { isSavingResult = false }

        do {
            let status = await requestPhotoLibraryAddPermission()
            guard Self.isPhotoLibraryAccessGranted(status) else {
                saveFeedback = SaveFeedback(
                    title: "Photos Access Needed",
                    message: "Please allow photo access so Calm can save generated content to your Photos.",
                    opensSettings: status == .denied || status == .restricted
                )
                return
            }

            if result.isVideo {
                try await Self.saveVideoToPhotoLibrary(from: result.url)
                saveFeedback = SaveFeedback(title: "Saved", message: "Your video has been saved to Photos.", opensSettings: false)
            } else {
                try await Self.saveImageToPhotoLibrary(from: result.url)
                saveFeedback = SaveFeedback(title: "Saved", message: "Your image has been saved to Photos.", opensSettings: false)
            }
        } catch {
            saveFeedback = SaveFeedback(
                title: "Save Failed",
                message: error.localizedDescription,
                opensSettings: false
            )
        }
    }

    private func requestPhotoLibraryAddPermission() async -> PHAuthorizationStatus {
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

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func actionButton(
        title: String,
        icon: String,
        fill: AnyShapeStyle,
        foreground: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foreground)
                } else {
                    Image(systemName: icon)
                }

                Text(title)
                    .font(.calm(16, weight: .bold))
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private static func isPhotoLibraryAccessGranted(_ status: PHAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    private static func saveImageToPhotoLibrary(from remoteURL: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: remoteURL)
        guard let image = UIImage(data: data) else {
            throw ResultSaveError.invalidImageData
        }

        try await performPhotoLibraryChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    private static func saveVideoToPhotoLibrary(from remoteURL: URL) async throws {
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
                    continuation.resume(throwing: ResultSaveError.saveFailed)
                }
            }
        }
    }
}

private enum ResultSaveError: LocalizedError {
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

private struct ResultLoopingVideoView: View {
    let url: URL
    let isPaused: Bool

    @StateObject private var playerEngine = ResultVideoEngine()

    var body: some View {
        ResultPlayerView(player: playerEngine.player)
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

private final class ResultVideoEngine: ObservableObject {
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
}

private struct ResultPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> ResultPlayerContainerView {
        let view = ResultPlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: ResultPlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspectFill
    }
}

private final class ResultPlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
