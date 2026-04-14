import Foundation

struct UploadImageResponse: Decodable {
    let success: Bool?
    let imageURLString: String?
    let fileName: String?
    let fileSize: Int?

    enum CodingKeys: String, CodingKey {
        case success
        case imageURLString = "image_url"
        case fileName = "file_name"
        case fileSize = "file_size"
    }

    var imageURL: URL? {
        guard let imageURLString, !imageURLString.isEmpty else { return nil }
        return URL(string: imageURLString)
    }
}

struct UploadVideoResponse: Decodable {
    let success: Bool?
    let videoURLString: String?
    let videoDurationSeconds: Double?
    let fileName: String?
    let fileSize: Int?

    enum CodingKeys: String, CodingKey {
        case success
        case videoURLString = "video_url"
        case videoDurationSeconds = "video_duration_seconds"
        case fileName = "file_name"
        case fileSize = "file_size"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try? container.decodeIfPresent(Bool.self, forKey: .success)
        videoURLString = try? container.decodeIfPresent(String.self, forKey: .videoURLString)
        videoDurationSeconds = container.decodeLossyDoubleIfPresent(forKey: .videoDurationSeconds)
        fileName = try? container.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = container.decodeLossyIntIfPresent(forKey: .fileSize)
    }

    var videoURL: URL? {
        guard let videoURLString, !videoURLString.isEmpty else { return nil }
        return URL(string: videoURLString)
    }
}

struct GenerationCreateResponse: Decodable {
    let success: Bool?
    let taskID: String?
    let outputURLString: String?
    let creditsUsed: Int?
    let creditsBalance: Int?
    let modelUsed: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case taskID = "task_id"
        case outputURLString = "output_url"
        case creditsUsed = "credits_used"
        case creditsBalance = "credits_balance"
        case modelUsed = "model_used"
        case message
    }

    var outputURL: URL? {
        guard let outputURLString, !outputURLString.isEmpty else { return nil }
        return URL(string: outputURLString)
    }
}

struct GenerationTaskStatusResponse: Decodable {
    let id: String?
    let status: String?
    let outputURLString: String?
    let errorMessage: String?
    let error: String?
    let creditsUsed: Int?
    let createdAt: String?
    let updatedAt: String?
    let progress: Double?
    let percentage: Double?
    let processingProgress: Double?
    let progressPercent: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case outputURLString = "output_url"
        case errorMessage = "error_message"
        case error
        case creditsUsed = "credits_used"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case progress
        case percentage
        case processingProgress = "processing_progress"
        case progressPercent = "progress_percent"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(String.self, forKey: .id)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        outputURLString = try? container.decodeIfPresent(String.self, forKey: .outputURLString)
        errorMessage = try? container.decodeIfPresent(String.self, forKey: .errorMessage)
        error = try? container.decodeIfPresent(String.self, forKey: .error)
        creditsUsed = container.decodeLossyIntIfPresent(forKey: .creditsUsed)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)
        progress = container.decodeLossyDoubleIfPresent(forKey: .progress)
        percentage = container.decodeLossyDoubleIfPresent(forKey: .percentage)
        processingProgress = container.decodeLossyDoubleIfPresent(forKey: .processingProgress)
        progressPercent = container.decodeLossyDoubleIfPresent(forKey: .progressPercent)
    }

    var outputURL: URL? {
        guard let outputURLString, !outputURLString.isEmpty else { return nil }
        return URL(string: outputURLString)
    }

    var normalizedProgress: Double? {
        let candidates = [progress, percentage, processingProgress, progressPercent].compactMap { $0 }
        guard let raw = candidates.first else { return nil }
        if raw > 1 {
            return min(max(raw / 100, 0), 0.99)
        }
        return min(max(raw, 0), 0.99)
    }

    var resolvedErrorMessage: String {
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        if let error, !error.isEmpty {
            return error
        }
        return "Generation failed"
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyDoubleIfPresent(forKey key: Key) -> Double? {
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }

    func decodeLossyIntIfPresent(forKey key: Key) -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }
}
