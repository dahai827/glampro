import Foundation
import UIKit

@MainActor
final class PreviewGenerationStore: ObservableObject {
    enum SubmissionState: Equatable {
        case idle
        case uploading(current: Int, total: Int)
        case creatingTask
        case readyToPoll
        case polling
        case completed
        case failed(String)
    }

    struct GeneratedTask: Equatable {
        let id: String
        let isVideo: Bool
    }

    struct GeneratedResult: Identifiable, Equatable {
        let id: String
        let url: URL
        let isVideo: Bool
    }

    @Published private(set) var activeItem: RemoteFeatureItem?
    @Published private(set) var selectedImages: [UIImage?] = [nil]
    @Published private(set) var submissionState: SubmissionState = .idle
    @Published private(set) var activeTask: GeneratedTask?
    @Published private(set) var result: GeneratedResult?
    @Published private(set) var observedTaskProgress: Double?
    @Published private(set) var lastFailureWasInsufficientCredits = false

    private let apiClient: APIClient
    private var isPolling = false

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var requiredImageCount: Int {
        guard let activeItem else { return 1 }

        if activeItem.enableImageMerge == true {
            return 2
        }

        if activeItem.materialRequirements.contains(where: { $0.type == "multiple_images" }) {
            return 2
        }

        if activeItem.materialRequirements.contains(where: { $0.type == "single_image" }) {
            return 1
        }

        switch normalizedModelType(activeItem.modelType) {
        case "text_to_image", "text_to_video":
            return 0
        default:
            return 1
        }
    }

    var hasSelection: Bool {
        selectedImages.contains { $0 != nil }
    }

    var canGenerate: Bool {
        if requiredImageCount == 0 {
            return true
        }
        return selectedImages.prefix(requiredImageCount).allSatisfy { $0 != nil }
    }

    var isSubmitting: Bool {
        switch submissionState {
        case .uploading, .creatingTask:
            return true
        default:
            return false
        }
    }

    var hasReadyResult: Bool {
        result != nil
    }

    var estimatedCreditsRequired: Int {
        activeItem?.estimatedCredits ?? 0
    }

    var currentErrorMessage: String? {
        if case let .failed(message) = submissionState {
            return message
        }
        return nil
    }

    var submitButtonTitle: String {
        switch submissionState {
        case let .uploading(current, total):
            return total > 1 ? "Uploading \(current)/\(total)..." : "Uploading Photo..."
        case .creatingTask:
            return "Creating Task..."
        default:
            return "Generate"
        }
    }

    var progressTitle: String {
        switch submissionState {
        case let .uploading(current, total):
            return total > 1 ? "Uploading source \(current) of \(total)..." : "Uploading your photo..."
        case .creatingTask:
            return "Creating AI task..."
        case .readyToPoll, .polling:
            return "AI is crafting your result..."
        case .completed:
            return "Result is ready"
        case let .failed(message):
            return message
        case .idle:
            return "Preparing your generation..."
        }
    }

    var progressSubtitle: String {
        switch submissionState {
        case .uploading:
            return "Optimizing and securely uploading your image."
        case .creatingTask:
            return "Submitting your request to the generation engine."
        case .readyToPoll, .polling:
            return "The background task usually finishes in about 1–3 minutes."
        case .completed:
            return "Opening the result preview now."
        case .failed:
            return "Please go back and try again."
        case .idle:
            return "Getting everything ready."
        }
    }

    func syncPreviewItem(_ item: RemoteFeatureItem?) {
        guard activeItem?.id != item?.id else { return }
        beginEditing(item: item)
    }

    func beginEditing(item: RemoteFeatureItem?) {
        activeItem = item
        let slots = max(requiredImageCount, 1)
        selectedImages = Array(repeating: nil, count: slots)
        submissionState = .idle
        activeTask = nil
        result = nil
        observedTaskProgress = nil
        lastFailureWasInsufficientCredits = false
    }

    func image(at index: Int) -> UIImage? {
        guard selectedImages.indices.contains(index) else { return nil }
        return selectedImages[index]
    }

    func setImage(_ image: UIImage, at index: Int) {
        ensureImageSlots()
        guard selectedImages.indices.contains(index) else { return }
        selectedImages[index] = image
        if case .failed = submissionState {
            submissionState = .idle
        }
    }

    func clearImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages[index] = nil
        if case .failed = submissionState {
            submissionState = .idle
        }
    }

    func clearAllImages() {
        selectedImages = Array(repeating: nil, count: max(requiredImageCount, 1))
        if case .failed = submissionState {
            submissionState = .idle
        }
    }

    func startGeneration(sessionManager: SessionManager) async throws {
        do {
            guard let item = activeItem else {
                throw APIError.missingData
            }

            guard canGenerate else {
                let count = requiredImageCount
                throw APIError.invalidStatusCode(400, count > 1 ? "Please upload \(count) photos first." : "Please upload a photo first.")
            }

            submissionState = .idle
            activeTask = nil
            result = nil
            observedTaskProgress = nil
            lastFailureWasInsufficientCredits = false

            let uploadedImageURLs = try await sessionManager.performAuthenticatedRequest { token in
                try await self.uploadSelectedImages(using: token)
            }

            submissionState = .creatingTask

            let response: GenerationCreateResponse = try await sessionManager.performAuthenticatedRequest { token in
                try await self.createGenerationRequest(
                    for: item,
                    uploadedImageURLs: uploadedImageURLs,
                    bearerToken: token
                )
            }

            if let creditsBalance = response.creditsBalance {
                sessionManager.applyCreditsBalance(creditsBalance)
            }

            let isVideo = isVideoModel(item.modelType)

            if let outputURL = response.outputURL {
                result = GeneratedResult(
                    id: response.taskID ?? UUID().uuidString,
                    url: outputURL,
                    isVideo: isVideo
                )
                observedTaskProgress = 1
                submissionState = .completed
                return
            }

            if let taskID = response.taskID, !taskID.isEmpty {
                activeTask = GeneratedTask(id: taskID, isVideo: isVideo)
                submissionState = .readyToPoll
                return
            }

            throw APIError.missingData
        } catch {
            lastFailureWasInsufficientCredits = Self.isInsufficientCreditsError(error)
            if lastFailureWasInsufficientCredits {
                await sessionManager.refreshUserStatus()
            }
            submissionState = .failed(error.localizedDescription)
            throw error
        }
    }

    func pollUntilResolved(sessionManager: SessionManager) async {
        guard let activeTask, result == nil, !isPolling else { return }
        isPolling = true
        defer { isPolling = false }

        submissionState = .polling

        do {
            while !Task.isCancelled {
                let taskResponse: GenerationTaskStatusResponse = try await sessionManager.performAuthenticatedRequest { token in
                    try await self.apiClient.get(
                        path: "get-task",
                        queryItems: [URLQueryItem(name: "task_id", value: activeTask.id)],
                        bearerToken: token
                    )
                }

                mergeObservedTaskProgress(taskResponse.normalizedProgress)

                let status = taskResponse.status?.lowercased() ?? "processing"
                switch status {
                case "completed":
                    guard let outputURL = taskResponse.outputURL else {
                        throw APIError.missingData
                    }
                    result = GeneratedResult(id: activeTask.id, url: outputURL, isVideo: activeTask.isVideo)
                    observedTaskProgress = 1
                    self.activeTask = nil
                    submissionState = .completed
                    return
                case "failed":
                    self.activeTask = nil
                    submissionState = .failed(taskResponse.resolvedErrorMessage)
                    return
                default:
                    submissionState = .polling
                }

                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        } catch is CancellationError {
            return
        } catch {
            self.activeTask = nil
            submissionState = .failed(error.localizedDescription)
        }
    }

    func resetTransientState() {
        submissionState = .idle
        activeTask = nil
        result = nil
        observedTaskProgress = nil
        lastFailureWasInsufficientCredits = false
    }

    func clearInsufficientCreditsFlag() {
        lastFailureWasInsufficientCredits = false
    }

    private static func isInsufficientCreditsError(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            if case let .invalidStatusCode(code, message) = apiError {
                if code == 403 && (message.localizedCaseInsensitiveContains("insufficient credits") || message.contains("积分不足")) {
                    return true
                }
            }
            if case let .transportError(message) = apiError {
                return message.localizedCaseInsensitiveContains("insufficient credits") || message.contains("积分不足")
            }
        }

        let message = error.localizedDescription
        return message.localizedCaseInsensitiveContains("insufficient credits") || message.contains("积分不足")
    }

    private func mergeObservedTaskProgress(_ progress: Double?) {
        guard let progress else { return }
        observedTaskProgress = max(observedTaskProgress ?? 0, min(max(progress, 0), 1))
    }

    private func ensureImageSlots() {
        let slots = max(requiredImageCount, 1)
        if selectedImages.count != slots {
            selectedImages = Array(selectedImages.prefix(slots)) + Array(repeating: nil, count: max(0, slots - selectedImages.count))
        }
    }

    private func uploadSelectedImages(using bearerToken: String) async throws -> [String] {
        let images = Array(selectedImages.prefix(requiredImageCount).compactMap { $0 })
        guard requiredImageCount == 0 || !images.isEmpty else {
            return []
        }

        var urls: [String] = []
        for (index, image) in images.enumerated() {
            submissionState = .uploading(current: index + 1, total: images.count)
            let compressedData = try await Self.prepareUploadData(for: image)
            let response = try await apiClient.uploadImage(
                data: compressedData,
                fileName: "input-\(UUID().uuidString).jpg",
                bearerToken: bearerToken
            )
            guard let url = response.imageURL?.absoluteString else {
                throw APIError.missingData
            }
            urls.append(url)
        }

        return urls
    }

    private func createGenerationRequest(
        for item: RemoteFeatureItem,
        uploadedImageURLs: [String],
        bearerToken: String
    ) async throws -> GenerationCreateResponse {
        let modelType = normalizedModelType(item.modelType)
        let path = generationPath(for: modelType)
        let prompt = resolvedPromptTemplate(from: item.promptTemplate)

        var payload: [String: Any] = [
            "item_id": item.id,
        ]

        switch modelType {
        case "image_to_image", "image_to_video":
            if item.enableImageMerge == true || uploadedImageURLs.count > 1 {
                payload["image_url"] = uploadedImageURLs
            } else {
                payload["image_url"] = uploadedImageURLs.first ?? ""
            }
        case "video_face_swap":
            payload["image_url"] = uploadedImageURLs.first ?? ""
        case "text_to_image", "text_to_video":
            break
        default:
            throw APIError.invalidStatusCode(400, "Unsupported model type: \(item.modelType ?? "unknown")")
        }

        if let prompt, !prompt.isEmpty {
            payload["prompt"] = prompt
        }

        let timeout: TimeInterval? = ["image_to_image", "image_to_video", "text_to_image", "video_face_swap"].contains(modelType) ? 180 : nil

        return try await apiClient.postJSON(
            path: path,
            jsonObject: payload,
            bearerToken: bearerToken,
            timeoutInterval: timeout
        )
    }

    private func generationPath(for modelType: String) -> String {
        switch modelType {
        case "image_to_image":
            return "image-to-image"
        case "image_to_video":
            return "image-to-video"
        case "text_to_image":
            return "text-to-image"
        case "text_to_video":
            return "text-to-video"
        case "video_face_swap":
            return "video-face-swap"
        default:
            return modelType.replacingOccurrences(of: "_", with: "-")
        }
    }

    private func normalizedModelType(_ modelType: String?) -> String {
        modelType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private func isVideoModel(_ modelType: String?) -> Bool {
        ["image_to_video", "text_to_video", "video_face_swap"].contains(normalizedModelType(modelType))
    }

    private func resolvedPromptTemplate(from template: String?) -> String? {
        let trimmed = template?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func prepareUploadData(for image: UIImage) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let maxDimension: CGFloat = 1024
            let maxBytes = 10 * 1024 * 1024

            let baseImage = image.normalizedOrientationImage()
            let resizedImage = baseImage.resizedToFit(maxDimension: maxDimension)

            var quality: CGFloat = 0.92
            while quality >= 0.35 {
                if let data = resizedImage.jpegData(compressionQuality: quality), data.count <= maxBytes {
                    return data
                }
                quality -= 0.12
            }

            if let fallback = resizedImage.jpegData(compressionQuality: 0.25) {
                return fallback
            }

            throw APIError.missingData
        }.value
    }
}

private extension UIImage {
    func normalizedOrientationImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedToFit(maxDimension: CGFloat) -> UIImage {
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
