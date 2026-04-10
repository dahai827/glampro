import SwiftUI
import AVFoundation
import UIKit
import Photos

struct FeaturesView: View {
    let onSelectFeature: (FeatureCardModel) -> Void
    let onClose: () -> Void

    @GestureState private var dragTranslation: CGFloat = 0

    private let columns = [
        GridItem(.flexible(), spacing: 18, alignment: .top),
        GridItem(.flexible(), spacing: 18, alignment: .top)
    ]

    private let dismissThreshold: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            // Keep only a slim reveal near Dynamic Island bottom across devices.
            let topReveal = min(max(proxy.safeAreaInsets.top - 26, 22), 34)
            let sheetHeight = max(proxy.size.height - topReveal, 520)

            ZStack(alignment: .bottom) {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                sheetBody(height: sheetHeight)
                    .offset(y: max(dragTranslation, 0))
                    .gesture(sheetDragGesture)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func sheetBody(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            Text("Features")
                .font(.calm(20, weight: .heavy))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)
                .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                    ForEach(MockData.featureCards) { item in
                        featureCard(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(CalmTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: -4)
    }

    private func featureCard(_ item: FeatureCardModel) -> some View {
        Button(action: { onSelectFeature(item) }) {
            VStack(alignment: .leading, spacing: 10) {
                PlaceholderArtwork(paletteIndex: item.paletteIndex, cornerRadius: 14, symbol: item.symbol)
                    .frame(height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.calm(14, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.calm(12, weight: .medium))
                        .foregroundColor(CalmTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = max(value.translation.height, 0)
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > dismissThreshold || value.predictedEndTranslation.height > 180
                if shouldDismiss {
                    onClose()
                }
            }
    }
}

struct AIChatView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isShowingMediaPicker = false
    @State private var showUploadSourceSheet = false
    @State private var selectedAttachmentMedia: FeaturePickedMedia?
    @State private var isSubmitting = false
    @State private var alertItem: FeatureAlertItem?
    @State private var chatMessages: [FeatureChatMessage] = []
    @State private var previewingImage: UIImage?
    @State private var previewingURL: URL?
    @State private var savingMessageIDs: Set<UUID> = []

    let onClose: () -> Void

    private let pageHorizontalPadding: CGFloat = 15
    private let inputPanelHorizontalPadding: CGFloat = 10
    private let inputPanelBottomPadding: CGFloat = 10
    private let contentBottomInset: CGFloat = 164

    var body: some View {
        ZStack(alignment: .bottom) {
            CalmTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerRow
                    .padding(.top, 8)

                introMessage
                    .padding(.top, 12)

                chatHistory
                    .padding(.top, 10)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, pageHorizontalPadding)
            .padding(.bottom, contentBottomInset)

            inputPanel
                .padding(.horizontal, inputPanelHorizontalPadding)
                .padding(.bottom, inputPanelBottomPadding)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay {
            if showUploadSourceSheet {
                FeatureUploadSourceSheet(
                    onClose: { showUploadSourceSheet = false },
                    onPickPhotoOrVideo: {
                        showUploadSourceSheet = false
                        pickerSource = .photoLibrary
                        isShowingMediaPicker = true
                    },
                    onPickCamera: {
                        showUploadSourceSheet = false
                        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                            alertItem = FeatureAlertItem(
                                title: "Camera Unavailable",
                                message: "This device does not support camera capture."
                            )
                            return
                        }
                        pickerSource = .camera
                        isShowingMediaPicker = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(30)
            }
        }
        .sheet(isPresented: $isShowingMediaPicker) {
            FeatureMediaPicker(sourceType: pickerSource) { media in
                selectedAttachmentMedia = media
            }
            .ignoresSafeArea()
        }
        .alert(item: $alertItem) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: Binding(
            get: { previewingImage != nil || previewingURL != nil },
            set: { if !$0 { previewingImage = nil; previewingURL = nil } }
        )) {
            FeatureImagePreviewSheet(image: previewingImage, imageURL: previewingURL)
                .ignoresSafeArea()
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            CircleIconButton(icon: "xmark", size: 34, action: onClose)

            HStack(spacing: 8) {
                BrandOrb(size: 24)
                Text("Glam AI")
                    .font(.calm(42, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button(action: clearAIChatSession) {
                Text("Clear")
                    .font(.calm(17, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 15)
                    .frame(height: 33)
                    .background(
                        Capsule()
                        .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func clearAIChatSession() {
        guard !isSubmitting else { return }
        chatMessages.removeAll()
        inputText = ""
        selectedAttachmentMedia = nil
        previewingImage = nil
        previewingURL = nil
    }

    private var introMessage: some View {
        Text("Hey! I’m Glam AI. Send me a photo and I’ll edit it however you want — change outfits, swap backgrounds, adjust details, or put people together in one scene. I can also create images from scratch and turn photos into videos. What should we make?")
            .font(.calm(15.5, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 84, height: 32)
                .overlay(
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("Tools")
                            .font(.calm(15, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.95))
                )

            if let selectedAttachmentMedia {
                HStack {
                    ZStack(alignment: .topTrailing) {
                        if let preview = selectedAttachmentMedia.previewImage {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 56, height: 56)
                        }

                        Button {
                            self.selectedAttachmentMedia = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.black.opacity(0.68)))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 8, y: -8)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                TextField("Describe your idea or ask", text: $inputText)
                    .font(.calm(17, weight: .medium))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .focused($isInputFocused)
                    .onSubmit {
                        guard !isSubmitting, canSubmitAIChat else { return }
                        Task { await submitAIChat() }
                    }

                Button(action: {
                    guard !isSubmitting else { return }
                    Task { await submitAIChat() }
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(canSubmitAIChat ? 0.95 : 0.42))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .stroke(Color.white.opacity(canSubmitAIChat ? 0.38 : 0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmitAIChat || isSubmitting)
            }

            HStack {
                Button(action: { showUploadSourceSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(selectedAttachmentMedia == nil ? .white.opacity(0.9) : .white.opacity(0.35))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(selectedAttachmentMedia == nil ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedAttachmentMedia != nil)

                if selectedAttachmentMedia != nil {
                    Text("1 selected")
                        .font(.calm(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(minHeight: 138)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }

    private var canSubmitAIChat: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var chatHistory: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(chatMessages) { message in
                    chatMessageRow(message)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func chatMessageRow(_ message: FeatureChatMessage) -> some View {
        HStack(spacing: 0) {
            if message.role == .user { Spacer(minLength: 46) }
            VStack(alignment: .leading, spacing: 8) {
                if let image = message.image {
                    Button {
                        previewingImage = image
                        previewingURL = message.imageURL
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 132, height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if let text = message.text, !text.isEmpty {
                    Text(text)
                        .font(.calm(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.92))
                }

                if message.role == .assistant, message.image != nil || message.imageURL != nil {
                    Button {
                        Task { await saveMessageImage(message) }
                    } label: {
                        Text(savingMessageIDs.contains(message.id) ? "Saving..." : "Save")
                            .font(.calm(12, weight: .bold))
                            .foregroundColor(.white.opacity(0.92))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(savingMessageIDs.contains(message.id))
                }

                if message.isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white.opacity(0.86))
                        Text("Generating...")
                            .font(.calm(13, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(message.role == .assistant ? 0.08 : 0.14))
            )
            .frame(maxWidth: 248, alignment: .leading)

            if message.role == .assistant { Spacer(minLength: 46) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private func submitAIChat() async {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            alertItem = FeatureAlertItem(title: "Prompt Required", message: "Please enter a prompt before sending.")
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let selectedMediaForRequest = selectedAttachmentMedia
        let userMessage = FeatureChatMessage(
            role: .user,
            text: prompt,
            image: selectedMediaForRequest?.previewImage,
            imageURL: nil,
            isGenerating: false
        )
        chatMessages.append(userMessage)
        let assistantPlaceholder = FeatureChatMessage(
            role: .assistant,
            text: nil,
            image: nil,
            imageURL: nil,
            isGenerating: true
        )
        chatMessages.append(assistantPlaceholder)
        let assistantID = assistantPlaceholder.id

        inputText = ""
        selectedAttachmentMedia = nil
        isInputFocused = false

        do {
            let response: GenerationCreateResponse = try await sessionManager.performAuthenticatedRequest { token in
                let imageURL = try await FeatureAPIBridge.uploadMediaIfNeeded(
                    selectedMediaForRequest,
                    apiClient: .shared,
                    bearerToken: token
                ) ?? ""

                return try await APIClient.shared.postJSON(
                    path: "image-to-image",
                    jsonObject: [
                        "item_id": "temp-qtu58rur6",
                        "prompt": prompt,
                        "image_url": imageURL
                    ],
                    bearerToken: token,
                    timeoutInterval: 180
                )
            }

            if let credits = response.creditsBalance {
                sessionManager.applyCreditsBalance(credits)
            }
            if let resolvedURL = try await FeatureAPIBridge.resolveOutputURL(
                from: response,
                fetchTaskStatus: { taskID in
                    try await sessionManager.performAuthenticatedRequest { token in
                        try await APIClient.shared.get(
                            path: "get-task",
                            queryItems: [URLQueryItem(name: "task_id", value: taskID)],
                            bearerToken: token
                        )
                    }
                }
            ) {
                let resultImage = try await FeatureAPIBridge.loadPreviewImage(from: resolvedURL)
                if let idx = chatMessages.firstIndex(where: { $0.id == assistantID }) {
                    chatMessages[idx] = FeatureChatMessage(
                        role: .assistant,
                        text: "Generated",
                        image: resultImage,
                        imageURL: resolvedURL,
                        isGenerating: false
                    )
                }
            } else {
                throw APIError.missingData
            }
        } catch {
            if let idx = chatMessages.firstIndex(where: { $0.id == assistantID }) {
                chatMessages[idx] = FeatureChatMessage(
                    role: .assistant,
                    text: "Request failed: \(error.localizedDescription)",
                    image: nil,
                    imageURL: nil,
                    isGenerating: false
                )
            }
            alertItem = FeatureAlertItem(title: "Request Failed", message: error.localizedDescription)
        }
    }

    @MainActor
    private func saveMessageImage(_ message: FeatureChatMessage) async {
        guard !savingMessageIDs.contains(message.id) else { return }
        savingMessageIDs.insert(message.id)
        defer { savingMessageIDs.remove(message.id) }

        do {
            if let image = message.image {
                try await FeatureAPIBridge.saveImageToPhotoLibrary(image)
            } else if let url = message.imageURL,
                      let image = try await FeatureAPIBridge.loadPreviewImage(from: url) {
                try await FeatureAPIBridge.saveImageToPhotoLibrary(image)
            } else {
                throw APIError.missingData
            }

            alertItem = FeatureAlertItem(title: "Saved", message: "Image saved to your Photos.")
        } catch {
            alertItem = FeatureAlertItem(title: "Save Failed", message: error.localizedDescription)
        }
    }
}

struct CustomStylesView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var previewGenerationStore: PreviewGenerationStore

    @State private var promptText = ""
    @FocusState private var isPromptFocused: Bool
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isShowingMediaPicker = false
    @State private var showUploadSourceSheet = false
    @State private var selectedMediaAsset: FeaturePickedMedia?
    @State private var submitStage: FeatureSubmitStage = .idle
    @State private var alertItem: FeatureAlertItem?

    let onClose: () -> Void

    private let pageHorizontalPadding: CGFloat = 15

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                CalmTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.top, 20)
                        .padding(.horizontal, pageHorizontalPadding)

                    imageCard
                        .padding(.top, 20)
                        .padding(.horizontal, pageHorizontalPadding)

                    promptCard
                        .padding(.top, 16)
                        .padding(.horizontal, pageHorizontalPadding)

                    generateSection
                        .padding(.top, 16)
                        .padding(.horizontal, pageHorizontalPadding)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .overlay {
            if showUploadSourceSheet {
                FeatureUploadSourceSheet(
                    onClose: { showUploadSourceSheet = false },
                    onPickPhotoOrVideo: {
                        showUploadSourceSheet = false
                        pickerSource = .photoLibrary
                        isShowingMediaPicker = true
                    },
                    onPickCamera: {
                        showUploadSourceSheet = false
                        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                            alertItem = FeatureAlertItem(
                                title: "Camera Unavailable",
                                message: "This device does not support camera capture."
                            )
                            return
                        }
                        pickerSource = .camera
                        isShowingMediaPicker = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(30)
            }
        }
        .sheet(isPresented: $isShowingMediaPicker) {
            FeatureMediaPicker(sourceType: pickerSource) { media in
                selectedMediaAsset = media
            }
            .ignoresSafeArea()
        }
        .alert(item: $alertItem) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var header: some View {
        ZStack {
            Text("Create Style")
                .font(.calm(22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack {
                CircleIconButton(icon: "xmark", size: 34, action: onClose)
                Spacer()
            }
        }
    }

    private var imageCard: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.11))
            .overlay {
                ZStack {
                    if let selectedMediaAsset, let preview = selectedMediaAsset.previewImage {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack {
                        Spacer()
                        Button(action: { showUploadSourceSheet = true }) {
                            Text("Change Image")
                                .font(.calm(18, weight: .bold))
                                .foregroundColor(Color.black.opacity(0.82))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.92))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 30)
                        Spacer()
                    }
                }
            }
            .frame(height: 208)
    }

    private var promptCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.88))

                Text("Select Generation Mode")
                    .font(.calm(16, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )

            ZStack(alignment: .topLeading) {
                TextEditor(text: $promptText)
                    .font(.calm(16, weight: .medium))
                    .foregroundColor(.white)
                    .modifier(FeatureHideScrollContentBackground())
                    .background(Color.clear)
                    .focused($isPromptFocused)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)

                if promptText.isEmpty {
                    Text("Describe how to modify\nyour Style")
                        .font(.calm(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.leading, 6)
                        .padding(.top, 10)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(height: 218)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
    }

    private var generateSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task { await submitCustomStyles() }
            }) {
                HStack(spacing: 8) {
                    if submitStage != .idle {
                        ProgressView()
                            .tint(Color.black.opacity(0.8))
                    }
                    Text(generateButtonTitle)
                        .font(.calm(18, weight: .bold))
                        .foregroundColor(generateButtonTextColor)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(generateButtonBackground)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmitCustomStyles)

            Text("1 Coin")
                .font(.calm(13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            if selectedMediaAsset != nil {
                Text("1 media selected")
                    .font(.calm(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var canSubmitCustomStyles: Bool {
        guard submitStage == .idle else { return false }
        return hasRequiredInputsForCustomStyles
    }

    private var hasRequiredInputsForCustomStyles: Bool {
        guard selectedMediaAsset != nil else { return false }
        return !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var generateButtonTitle: String {
        switch submitStage {
        case .idle:
            return "Generate"
        case .uploading:
            return "Uploading Photo..."
        case .creatingTask:
            return "Creating Task..."
        }
    }

    private var generateButtonBackground: Color {
        (hasRequiredInputsForCustomStyles || submitStage != .idle) ? Color.white.opacity(0.94) : Color.white.opacity(0.1)
    }

    private var generateButtonTextColor: Color {
        (hasRequiredInputsForCustomStyles || submitStage != .idle) ? Color.black.opacity(0.86) : Color.white.opacity(0.42)
    }

    private func submitCustomStyles() async {
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            alertItem = FeatureAlertItem(title: "Prompt Required", message: "Please enter prompt text before generating.")
            return
        }
        guard let selectedMediaForSubmit = selectedMediaAsset else {
            alertItem = FeatureAlertItem(title: "Image Required", message: "Please upload an image or video first.")
            return
        }

        submitStage = .uploading
        defer { submitStage = .idle }

        do {
            let response: GenerationCreateResponse = try await sessionManager.performAuthenticatedRequest { token in
                guard let imageURL = try await FeatureAPIBridge.uploadMediaIfNeeded(
                    selectedMediaForSubmit,
                    apiClient: .shared,
                    bearerToken: token
                ), !imageURL.isEmpty else {
                    throw APIError.missingData
                }

                await MainActor.run {
                    submitStage = .creatingTask
                }

                return try await APIClient.shared.postJSON(
                    path: "image-to-image",
                    jsonObject: [
                        "item_id": "temp-p2inhg10f",
                        "prompt": prompt,
                        "image_url": imageURL
                    ],
                    bearerToken: token,
                    timeoutInterval: 180
                )
            }

            if let credits = response.creditsBalance {
                sessionManager.applyCreditsBalance(credits)
            }

            guard let flowItem = FeatureAPIBridge.makeFeatureFlowItem(
                id: "temp-p2inhg10f",
                title: "Custom Styles",
                modelType: "image_to_image",
                prompt: prompt,
                estimatedCredits: 1
            ) else {
                throw APIError.missingData
            }

            previewGenerationStore.beginExternalGeneration(item: flowItem)
            try previewGenerationStore.completeExternalGenerationCreation(with: response, isVideo: false)
            promptText = ""
            selectedMediaAsset = nil
            appState.replace(with: .generationProgress)
        } catch {
            alertItem = FeatureAlertItem(title: "Request Failed", message: error.localizedDescription)
        }
    }
}

struct MotionSwapView: View {
    let onClose: () -> Void

    private let pageHorizontalPadding: CGFloat = 15

    var body: some View {
        ZStack {
            CalmTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 20)
                    .padding(.horizontal, pageHorizontalPadding)

                uploadCards
                    .padding(.top, 16)
                    .padding(.horizontal, pageHorizontalPadding)

                motionPromptCard
                    .padding(.top, 16)
                    .padding(.horizontal, pageHorizontalPadding)

                generateSection
                    .padding(.top, 16)
                    .padding(.horizontal, pageHorizontalPadding)

                Spacer(minLength: 4)

                generationsPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var header: some View {
        ZStack {
            Text("Create Style")
                .font(.calm(22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack {
                CircleIconButton(icon: "xmark", size: 34, action: onClose)
                Spacer()
            }
        }
    }

    private var uploadCards: some View {
        HStack(spacing: 8) {
            uploadCard(
                title: "Pick a photo for\nyour character",
                buttonTitle: "Add Image"
            )

            uploadCard(
                title: "The motion from\nthe video will be\napplied to your\nimage",
                buttonTitle: "Add Video"
            )
        }
        .frame(height: 198)
    }

    private func uploadCard(title: String, buttonTitle: String) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.11))
            .overlay {
                VStack(spacing: 18) {
                    Text(title)
                        .font(.calm(13, weight: .bold))
                        .foregroundColor(.white.opacity(0.52))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1.4)
                        .frame(height: 66, alignment: .top)

                    Button(action: {}) {
                        Text(buttonTitle)
                            .font(.calm(16, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 0)
                }
                .padding(.top, 18)
            }
    }

    private var motionPromptCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.88))

                Text("Motion Swap")
                    .font(.calm(16, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.clear)
                .overlay(alignment: .topLeading) {
                    Text("A character dances")
                        .font(.calm(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))
                        .padding(.leading, 6)
                        .padding(.top, 12)
                }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(height: 218)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
    }

    private var generateSection: some View {
        VStack(spacing: 8) {
            Button(action: {}) {
                Text("Generate")
                    .font(.calm(18, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            Text("1 Coin")
                .font(.calm(13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var generationsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 50, height: 5)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)

            Text("My Generations")
                .font(.calm(18, weight: .bold))
                .foregroundColor(.white.opacity(0.58))
                .padding(.top, 14)
                .padding(.horizontal, 15)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 154)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct FeatureHideScrollContentBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
                .onAppear {
                    UITextView.appearance().backgroundColor = .clear
                }
        }
    }
}

private struct FeatureAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum FeatureSubmitStage {
    case idle
    case uploading
    case creatingTask
}

private struct FeatureChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String?
    let image: UIImage?
    let imageURL: URL?
    let isGenerating: Bool
}

private struct FeatureImagePreviewSheet: View {
    let image: UIImage?
    let imageURL: URL?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                        case .failure:
                            Text("Failed to load")
                                .font(.calm(16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        default:
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            .padding(.top, 14)
        }
    }
}

private enum FeaturePickedMedia {
    case image(UIImage)
    case video(URL)
}

private extension FeaturePickedMedia {
    var previewImage: UIImage? {
        switch self {
        case .image(let image):
            return image
        case .video(let url):
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 900, height: 900)
            if let cgImage = try? generator.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil) {
                return UIImage(cgImage: cgImage)
            }
            return nil
        }
    }
}

private enum FeatureAPIBridge {
    static func uploadMediaIfNeeded(
        _ media: FeaturePickedMedia?,
        apiClient: APIClient,
        bearerToken: String
    ) async throws -> String? {
        guard let media else { return nil }

        switch media {
        case .image(let image):
            let data = try await prepareImageUploadData(image)
            let response = try await apiClient.uploadImage(
                data: data,
                fileName: "feature-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                bearerToken: bearerToken
            )
            return response.imageURL?.absoluteString
        case .video(let url):
            let (data, fileName, mimeType) = try await prepareVideoUploadData(url)
            let response = try await apiClient.uploadImage(
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                bearerToken: bearerToken
            )
            return response.imageURL?.absoluteString
        }
    }

    private static func prepareImageUploadData(_ image: UIImage) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let maxDimension: CGFloat = 1024
            let maxBytes = 10 * 1024 * 1024

            let normalized = image.featureNormalizedOrientationImage()
            let resized = normalized.featureResizedToFit(maxDimension: maxDimension)

            var quality: CGFloat = 0.92
            while quality >= 0.35 {
                if let data = resized.jpegData(compressionQuality: quality), data.count <= maxBytes {
                    return data
                }
                quality -= 0.12
            }

            if let fallback = resized.jpegData(compressionQuality: 0.25) {
                return fallback
            }

            throw APIError.missingData
        }.value
    }

    private static func prepareVideoUploadData(_ url: URL) async throws -> (Data, String, String) {
        try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()
            let fileName = "feature-\(UUID().uuidString).\(ext.isEmpty ? "mp4" : ext)"
            let mimeType: String
            if ext == "mov" {
                mimeType = "video/quicktime"
            } else {
                mimeType = "video/mp4"
            }
            return (data, fileName, mimeType)
        }.value
    }

    static func loadPreviewImage(from url: URL) async throws -> UIImage? {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            return nil
        }
        return UIImage(data: data)
    }

    static func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        let authStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authStatus == .authorized || authStatus == .limited else {
            throw APIError.transportError("Photo permission denied. Please allow Photos access in Settings.")
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? APIError.transportError("Failed to save image."))
                }
            }
        }
    }

    static func resolveOutputURL(
        from response: GenerationCreateResponse,
        fetchTaskStatus: @escaping (_ taskID: String) async throws -> GenerationTaskStatusResponse
    ) async throws -> URL? {
        if let outputURL = response.outputURL {
            return outputURL
        }

        guard let taskID = response.taskID?.trimmingCharacters(in: .whitespacesAndNewlines), !taskID.isEmpty else {
            return nil
        }

        for _ in 0..<24 {
            try Task.checkCancellation()
            let taskResponse = try await fetchTaskStatus(taskID)

            let status = taskResponse.status?.lowercased() ?? ""
            if status == "completed" {
                return taskResponse.outputURL
            }
            if status == "failed" {
                throw APIError.transportError(taskResponse.resolvedErrorMessage)
            }

            try await Task.sleep(nanoseconds: 3_000_000_000)
        }

        throw APIError.transportError("Generation is still processing. Please check your history and try again later.")
    }

    static func makeFeatureFlowItem(
        id: String,
        title: String,
        modelType: String,
        prompt: String,
        estimatedCredits: Int
    ) -> RemoteFeatureItem? {
        let payload: [String: Any] = [
            "id": id,
            "title": title,
            "model_type": modelType,
            "estimated_credits": estimatedCredits,
            "prompt_template": prompt,
            "material_requirements": [["type": "single_image"]]
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let item = try? JSONDecoder().decode(RemoteFeatureItem.self, from: data) else {
            return nil
        }
        return item
    }
}

private extension UIImage {
    func featureNormalizedOrientationImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func featureResizedToFit(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension, largestSide > 0 else { return self }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private struct FeatureMediaPicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onMediaPicked: (FeaturePickedMedia) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onMediaPicked: onMediaPicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.videoQuality = .typeHigh
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onMediaPicked: (FeaturePickedMedia) -> Void
        let dismiss: DismissAction

        init(onMediaPicked: @escaping (FeaturePickedMedia) -> Void, dismiss: DismissAction) {
            self.onMediaPicked = onMediaPicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let mediaType = info[.mediaType] as? String {
                if mediaType == "public.movie", let videoURL = info[.mediaURL] as? URL {
                    onMediaPicked(.video(videoURL))
                } else if let image = info[.originalImage] as? UIImage {
                    onMediaPicked(.image(image))
                }
            }
            dismiss()
        }
    }
}

private struct FeatureUploadSourceSheet: View {
    let onClose: () -> Void
    let onPickPhotoOrVideo: () -> Void
    let onPickCamera: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 14) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)

                Text("Choose Media")
                    .font(.calm(18, weight: .heavy))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    option(icon: "photo.fill", title: "Pick Photo or Video", action: onPickPhotoOrVideo)
                    option(icon: "camera.fill", title: "Camera", action: onPickCamera)
                }
                .padding(.horizontal, 16)

                Button("Cancel", action: onClose)
                    .font(.calm(16, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CalmTheme.elevated)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }

    private func option(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 94)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundColor(.white)
                    )

                Text(title)
                    .font(.calm(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
