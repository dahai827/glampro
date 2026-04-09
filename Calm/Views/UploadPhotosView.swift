import SwiftUI
import UIKit

struct UploadPhotosView: View {
    @EnvironmentObject private var appBootstrap: AppBootstrapStore
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var previewGenerationStore: PreviewGenerationStore

    let onClose: () -> Void
    let onGenerate: () -> Void
    let onInsufficientCredits: () -> Void

    @State private var activeSlotIndex = 0
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isShowingImagePicker = false
    @State private var showCameraAlert = false

    private var item: RemoteFeatureItem? {
        previewGenerationStore.activeItem ?? appBootstrap.selectedPreviewItem
    }

    private var imageSlotCount: Int {
        max(previewGenerationStore.requiredImageCount, 1)
    }

    var body: some View {
        ZStack {
            CalmTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    topBar
                    headerCard
                    sourceButtons
                    slotSection
                    errorCard
                    tipsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isShowingImagePicker) {
            LegacyImagePicker(sourceType: pickerSource) { image in
                previewGenerationStore.setImage(image, at: activeSlotIndex)
            }
            .ignoresSafeArea()
        }
        .alert("Camera Unavailable", isPresented: $showCameraAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not support camera capture.")
        }
        .task(id: item?.id) {
            previewGenerationStore.syncPreviewItem(item)
            activeSlotIndex = 0
        }
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(icon: "xmark", action: onClose)
            Spacer(minLength: 0)
            Text("Choose Media")
                .font(.calm(20, weight: .heavy))
                .foregroundColor(.white)
            Spacer(minLength: 0)
            if previewGenerationStore.hasSelection {
                Button("Clear") {
                    previewGenerationStore.clearAllImages()
                    activeSlotIndex = 0
                }
                .font(.calm(15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, alignment: .trailing)
            } else {
                Color.clear.frame(width: 44, height: 34)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item?.title ?? "Upload your photo")
                .font(.calm(24, weight: .heavy))
                .foregroundColor(.white)

            Text(item?.displaySubtitle ?? "Pick a clear photo to start creating with AI.")
                .font(.calm(15, weight: .medium))
                .foregroundColor(CalmTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                Text(requirementText)
                    .font(.calm(13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CalmTheme.elevated)
        )
    }

    private var sourceButtons: some View {
        HStack(spacing: 12) {
            pickOption(icon: "photo.fill", title: "Pick Photo") {
                activeSlotIndex = min(activeSlotIndex, imageSlotCount - 1)
                pickerSource = .photoLibrary
                isShowingImagePicker = true
            }

            pickOption(icon: "camera.fill", title: "Camera") {
                activeSlotIndex = min(activeSlotIndex, imageSlotCount - 1)
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    showCameraAlert = true
                    return
                }
                pickerSource = .camera
                isShowingImagePicker = true
            }

            Spacer(minLength: 0)
        }
    }

    private var slotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(imageSlotCount > 1 ? "Upload Photos" : "Upload Photo")
                .font(.calm(17, weight: .bold))
                .foregroundColor(.white)

            ForEach(0..<imageSlotCount, id: \.self) { index in
                mediaSlot(index: index)
            }
        }
    }

    @ViewBuilder
    private var errorCard: some View {
        if let message = previewGenerationStore.currentErrorMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CalmTheme.orange)
                Text(message)
                    .font(.calm(14, weight: .medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "3A241D"))
            )
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tips")
                .font(.calm(16, weight: .bold))
                .foregroundColor(.white)

            tipRow("Use a clear front-facing photo.")
            tipRow("Avoid blurry or dark images.")
            tipRow("You can replace a slot anytime before generating.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CalmTheme.elevated)
        )
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    previewGenerationStore.clearInsufficientCreditsFlag()

                    if shouldPromptForCreditPurchase {
                        onInsufficientCredits()
                        return
                    }

                    do {
                        try await previewGenerationStore.startGeneration(sessionManager: sessionManager)
                        onGenerate()
                    } catch {
                        if previewGenerationStore.lastFailureWasInsufficientCredits {
                            onInsufficientCredits()
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if previewGenerationStore.isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(previewGenerationStore.submitButtonTitle)
                        .font(.calm(18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(previewGenerationStore.canGenerate ? CalmTheme.accentGradient : LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
            .disabled(!previewGenerationStore.canGenerate || previewGenerationStore.isSubmitting)

            Text(item?.creditsText ?? "")
                .font(.calm(14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var shouldPromptForCreditPurchase: Bool {
        let requiredCredits = previewGenerationStore.estimatedCreditsRequired
        guard requiredCredits > 0 else { return false }
        return sessionManager.creditsBalance < requiredCredits
    }

    private func mediaSlot(index: Int) -> some View {
        let image = previewGenerationStore.image(at: index)
        let isActive = activeSlotIndex == index

        return Button {
            activeSlotIndex = index
        } label: {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 180)
                    .overlay {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(14)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "photo")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.72))
                                Text(slotTitle(index: index))
                                    .font(.calm(15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Tap to select, then choose Photo or Camera above")
                                    .font(.calm(13, weight: .medium))
                                    .foregroundColor(CalmTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 18)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isActive ? Color.white.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isActive ? 1.2 : 1)
                    )

                HStack(spacing: 8) {
                    Text(image == nil ? "Empty" : "Ready")
                        .font(.calm(12, weight: .bold))
                        .foregroundColor(.white)

                    if image != nil {
                        Button {
                            previewGenerationStore.clearImage(at: index)
                            activeSlotIndex = index
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.black.opacity(0.35)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
        }
        .buttonStyle(.plain)
    }

    private func pickOption(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 120, height: 100)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    )

                Text(title)
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private func tipRow(_ title: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(CalmTheme.purple)
            Text(title)
                .font(.calm(14, weight: .medium))
                .foregroundColor(CalmTheme.secondaryText)
        }
    }

    private func slotTitle(index: Int) -> String {
        imageSlotCount > 1 ? "Photo \(index + 1)" : "Upload Image"
    }

    private var requirementText: String {
        imageSlotCount > 1 ? "Upload \(imageSlotCount) photos to continue" : "Upload 1 photo to continue"
    }
}

private struct LegacyImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }
    }
}
