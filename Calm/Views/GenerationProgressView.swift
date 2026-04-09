import SwiftUI

struct GenerationProgressView: View {
    @EnvironmentObject private var previewGenerationStore: PreviewGenerationStore
    @EnvironmentObject private var sessionManager: SessionManager

    let onClose: () -> Void
    let onShowResult: () -> Void

    @State private var displayedProgress: CGFloat = 0.06
    @State private var pollingTask: Task<Void, Never>?
    @State private var progressLoopTask: Task<Void, Never>?
    @State private var resultRoutingTask: Task<Void, Never>?
    @State private var pollingStartedAt: Date?
    @State private var didRouteToResult = false

    private let generationFloor: CGFloat = 0.12
    private let generationCeiling: CGFloat = 0.90
    private let fallbackDuration: TimeInterval = 30

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom

            VStack(spacing: 0) {
                topBar(topInset: safeTop)

                Spacer(minLength: 24)

                heroCard
                    .padding(.horizontal, 16)

                Spacer(minLength: 18)

                if case .failed = previewGenerationStore.submissionState {
                    footerPanel(bottomInset: safeBottom)
                        .padding(.horizontal, 16)
                } else {
                    Color.clear
                        .frame(height: max(safeBottom, 12))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .clipped()
            .background {
                ZStack {
                    backgroundLayer

                    LinearGradient(
                        colors: [Color.black.opacity(0.26), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .ignoresSafeArea()

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.18), Color.black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
        }
        .onAppear(perform: handleAppear)
        .onDisappear(perform: cancelTasks)
        .onChange(of: previewGenerationStore.submissionState) { _ in
            handleStateChanged()
        }
        .onChange(of: previewGenerationStore.observedTaskProgress) { _ in
            refreshDisplayedProgress(animated: true)
        }
        .onChange(of: previewGenerationStore.result?.id) { _ in
            routeToResultIfNeeded()
        }
    }

    private var backgroundLayer: some View {
        let paletteIndex = abs((previewGenerationStore.activeItem?.id ?? "generation-progress").hashValue) % 8

        return ZStack {
            RemoteArtworkView(
                url: previewGenerationStore.activeItem?.effectiveCoverURL,
                paletteIndex: paletteIndex,
                cornerRadius: 0,
                contentMode: .fill
            )
            .ignoresSafeArea()
            .scaleEffect(1.08)
            .blur(radius: 24)

            Color.black.opacity(0.48)
                .ignoresSafeArea()
        }
    }

    private func topBar(topInset: CGFloat) -> some View {
        HStack(spacing: 12) {
            CircleIconButton(icon: "chevron.left", size: 40, action: onClose)

            Spacer(minLength: 0)

            creditsPill
        }
        .padding(.horizontal, 16)
        .padding(.top, topInset + 8)
        .overlay {
            Text("Generating")
                .font(.calm(18, weight: .heavy))
                .foregroundColor(.white)
        }
    }

    private var creditsPill: some View {
        Text(sessionManager.creditsBalance > 0 ? "\(sessionManager.creditsBalance) Credits" : (previewGenerationStore.activeItem?.creditsText ?? "AI Task"))
            .font(.calm(13, weight: .bold))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                pillLabel(title: stageDisplayTitle, icon: stageIcon, tint: CalmTheme.purple)
                pillLabel(title: progressModePillTitle, icon: progressModeIcon, tint: progressModeTint)
                pillLabel(title: resultTypePillTitle, icon: previewGenerationStore.activeTask?.isVideo == true ? "video.fill" : "photo.fill", tint: CalmTheme.orange)
            }

            Text(cardTitle)
                .font(.calm(28, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(2)

            Text(cardSubtitle)
                .font(.calm(15, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 18) {
                GenerationHeroRing(progress: displayedProgress, percentText: progressPercentText, statusText: progressModeShortText)
                    .frame(width: 164, height: 164)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(previewGenerationStore.progressTitle)
                            .font(.calm(15, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 10)

                        Text(progressPercentText)
                            .font(.calm(16, weight: .heavy))
                            .foregroundColor(.white)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.10))

                            Capsule()
                                .fill(CalmTheme.accentGradient)
                                .frame(width: progressBarWidth(totalWidth: proxy.size.width))
                        }
                    }
                    .frame(height: 8)
                }

                HStack(spacing: 10) {
                    infoBadge(title: progressSourceTitle, value: progressSourceValue)
                    infoBadge(title: "Status", value: progressStatusValue)
                    infoBadge(title: "Task", value: previewGenerationStore.activeTask?.isVideo == true ? "Video" : "Image")
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func footerPanel(bottomInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: footerIcon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(footerTint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 6) {
                    Text(footerTitle)
                        .font(.calm(15, weight: .bold))
                        .foregroundColor(.white)

                    Text(footerBody)
                        .font(.calm(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if case .failed = previewGenerationStore.submissionState {
                Button(action: onClose) {
                    Text("Back to Edit")
                        .font(.calm(17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CalmTheme.accentGradient)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, max(bottomInset, 12) + 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var cardTitle: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "Your result is ready"
        case .failed:
            return "Generation needs attention"
        default:
            return previewGenerationStore.activeItem?.title ?? "Creating your result"
        }
    }

    private var cardSubtitle: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "The result is ready. We are opening the preview now."
        case .failed:
            return "The task stopped before completion. You can go back and try again."
        default:
            return previewGenerationStore.activeItem?.displaySubtitle ?? "Stay on this screen while Calm AI finishes your creation."
        }
    }

    private var stageDisplayTitle: String {
        switch previewGenerationStore.submissionState {
        case .uploading:
            return "Uploading"
        case .creatingTask:
            return "Queueing"
        case .readyToPoll, .polling:
            return "Generating"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .idle:
            return "Preparing"
        }
    }

    private var stageIcon: String {
        switch previewGenerationStore.submissionState {
        case .uploading:
            return "arrow.up.circle.fill"
        case .creatingTask:
            return "paperplane.fill"
        case .readyToPoll, .polling:
            return "sparkles"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .idle:
            return "clock.fill"
        }
    }

    private var resultTypePillTitle: String {
        previewGenerationStore.activeTask?.isVideo == true ? "Video" : "Image"
    }

    private var progressModePillTitle: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "Ready"
        case .failed:
            return "Stopped"
        case .readyToPoll, .polling:
            return previewGenerationStore.observedTaskProgress == nil ? "Estimated" : "Live Sync"
        default:
            return "Preparing"
        }
    }

    private var progressModeShortText: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "READY"
        case .failed:
            return "ERROR"
        case .readyToPoll, .polling:
            return previewGenerationStore.observedTaskProgress == nil ? "EST." : "LIVE"
        default:
            return "SYNC"
        }
    }

    private var progressModeIcon: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "checkmark.seal.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .readyToPoll, .polling:
            return previewGenerationStore.observedTaskProgress == nil ? "clock.arrow.circlepath" : "waveform.path.ecg"
        default:
            return "slider.horizontal.3"
        }
    }

    private var progressModeTint: Color {
        switch previewGenerationStore.submissionState {
        case .completed:
            return CalmTheme.orange
        case .failed:
            return Color.red.opacity(0.82)
        case .readyToPoll, .polling:
            return previewGenerationStore.observedTaskProgress == nil ? CalmTheme.blue : CalmTheme.orange
        default:
            return CalmTheme.blue
        }
    }

    private var progressSourceTitle: String {
        previewGenerationStore.observedTaskProgress == nil ? "Progress" : "Source"
    }

    private var progressSourceValue: String {
        if case .completed = previewGenerationStore.submissionState {
            return "Done"
        }
        if case .failed = previewGenerationStore.submissionState {
            return "Stopped"
        }
        return previewGenerationStore.observedTaskProgress == nil ? "Estimated" : "Server"
    }

    private var progressStatusValue: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "Ready"
        case .failed:
            return "Error"
        case .readyToPoll, .polling:
            return previewGenerationStore.observedTaskProgress == nil ? "Waiting" : "Live"
        case .creatingTask:
            return "Queue"
        case .uploading:
            return "Upload"
        case .idle:
            return "Setup"
        }
    }

    private var progressPercentText: String {
        "\(Int((displayedProgress * 100).rounded()))%"
    }

    private var footerIcon: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .readyToPoll, .polling:
            return previewGenerationStore.observedTaskProgress == nil ? "hourglass.bottomhalf.filled" : "bolt.horizontal.circle.fill"
        case .creatingTask:
            return "paperplane.fill"
        case .uploading:
            return "arrow.up.circle.fill"
        case .idle:
            return "sparkles"
        }
    }

    private var footerTint: Color {
        switch previewGenerationStore.submissionState {
        case .failed:
            return CalmTheme.orange
        case .completed:
            return CalmTheme.orange
        case .readyToPoll, .polling:
            return previewGenerationStore.observedTaskProgress == nil ? CalmTheme.blue : CalmTheme.orange
        default:
            return CalmTheme.purple
        }
    }

    private var footerTitle: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "Result received"
        case .failed:
            return "Generation failed"
        case .readyToPoll, .polling:
            return previewGenerationStore.observedTaskProgress == nil ? "Estimated progress is active" : "Live progress is synced"
        case .creatingTask:
            return "Creating your task"
        case .uploading:
            return "Uploading source media"
        case .idle:
            return "Preparing generation"
        }
    }

    private var footerBody: String {
        switch previewGenerationStore.submissionState {
        case .completed:
            return "The result has been returned by the server. We will jump to the preview in a moment."
        case let .failed(message):
            return message
        case .readyToPoll, .polling:
            if previewGenerationStore.observedTaskProgress == nil {
                return "If the API does not return a live percentage, the bar reaches about 90% in roughly 30 seconds and finishes when the result is ready."
            }
            return "The progress bar is following the task percentage returned by the server and stays in sync with the current generation state."
        case .creatingTask:
            return "We are submitting your request to the generation engine."
        case .uploading:
            return "Optimizing and securely uploading your selected media."
        case .idle:
            return "Getting everything ready before the task starts."
        }
    }

    private func pillLabel(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.calm(11, weight: .bold))
        }
        .foregroundColor(.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(tint.opacity(0.16)))
    }

    private func infoBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.calm(11, weight: .bold))
                .foregroundColor(.white.opacity(0.52))
            Text(value)
                .font(.calm(14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func handleAppear() {
        ensurePollingStartDateIfNeeded(resetIfNeeded: true)
        refreshDisplayedProgress(animated: false)
        startProgressLoop()
        startPollingIfNeeded()
        routeToResultIfNeeded()
    }

    private func handleStateChanged() {
        ensurePollingStartDateIfNeeded(resetIfNeeded: false)
        refreshDisplayedProgress(animated: true)
        routeToResultIfNeeded()
    }

    private func startPollingIfNeeded() {
        guard previewGenerationStore.result == nil else { return }
        pollingTask?.cancel()
        pollingTask = Task {
            await previewGenerationStore.pollUntilResolved(sessionManager: sessionManager)
        }
    }

    private func startProgressLoop() {
        progressLoopTask?.cancel()
        progressLoopTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    refreshDisplayedProgress(animated: true)
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func cancelTasks() {
        pollingTask?.cancel()
        progressLoopTask?.cancel()
        resultRoutingTask?.cancel()
        pollingTask = nil
        progressLoopTask = nil
        resultRoutingTask = nil
    }

    private func routeToResultIfNeeded() {
        guard previewGenerationStore.result != nil, !didRouteToResult else { return }
        didRouteToResult = true
        resultRoutingTask?.cancel()
        resultRoutingTask = Task {
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.28)) {
                    displayedProgress = 1
                }
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onShowResult()
            }
        }
    }

    private func ensurePollingStartDateIfNeeded(resetIfNeeded: Bool) {
        switch previewGenerationStore.submissionState {
        case .readyToPoll, .polling:
            if pollingStartedAt == nil {
                pollingStartedAt = Date()
            }
        case .idle, .uploading, .creatingTask:
            if resetIfNeeded {
                pollingStartedAt = nil
            }
        case .completed, .failed:
            break
        }
    }

    private func refreshDisplayedProgress(animated: Bool) {
        let target = max(displayedProgress, progressTarget)
        guard abs(target - displayedProgress) > 0.001 else { return }

        if animated {
            withAnimation(.easeOut(duration: previewGenerationStore.result == nil ? 0.18 : 0.28)) {
                displayedProgress = target
            }
        } else {
            displayedProgress = target
        }
    }

    private var progressTarget: CGFloat {
        switch previewGenerationStore.submissionState {
        case .idle:
            return 0.05
        case let .uploading(current, total):
            let denominator = max(total, 1)
            return min(0.10, 0.04 + (CGFloat(current) / CGFloat(denominator)) * 0.06)
        case .creatingTask:
            return generationFloor
        case .readyToPoll, .polling:
            if let serverProgress = previewGenerationStore.observedTaskProgress {
                return mappedGenerationProgress(serverProgress)
            }
            return fallbackGenerationProgress
        case .completed:
            return 1
        case .failed:
            return min(max(displayedProgress, 0.12), generationCeiling)
        }
    }

    private var fallbackGenerationProgress: CGFloat {
        guard let pollingStartedAt else { return generationFloor }
        let elapsed = max(0, Date().timeIntervalSince(pollingStartedAt))
        let fraction = min(CGFloat(elapsed / fallbackDuration), 1)
        return generationFloor + (generationCeiling - generationFloor) * fraction
    }

    private func mappedGenerationProgress(_ serverProgress: Double) -> CGFloat {
        let normalized = min(max(CGFloat(serverProgress), 0), 1)
        return generationFloor + (generationCeiling - generationFloor) * normalized
    }

    private func progressBarWidth(totalWidth: CGFloat) -> CGFloat {
        let rawWidth = totalWidth * displayedProgress
        if rawWidth <= 0 {
            return 0
        }
        return min(totalWidth, max(18, rawWidth))
    }
}

private struct GenerationHeroRing: View {
    let progress: CGFloat
    let percentText: String
    let statusText: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [CalmTheme.pink, CalmTheme.orange, CalmTheme.purple, CalmTheme.pink],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(Color.black.opacity(0.16))
                .padding(18)

            VStack(spacing: 6) {
                Text(percentText)
                    .font(.calm(30, weight: .heavy))
                    .foregroundColor(.white)

                Text(statusText)
                    .font(.calm(11, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(.white.opacity(0.60))
            }
        }
    }
}
