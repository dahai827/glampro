import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://api.streamflowai.store/functions/v1")!
    static let supabaseURL = URL(string: "https://api.streamflowai.store")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyZW5sZ3FwcHZxZmJpYnhwcGJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1MTIxODMsImV4cCI6MjA3ODA4ODE4M30.xVbKv4Es1sZRtWYsqbcu4eBoL1XZlMcyLcEJTTpddP4"
    static let appID = "glampro"
    static let defaultPageType = "default"

    static var appVersion: String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !version.isEmpty {
            return version
        }
        return "1.0.0"
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case invalidStatusCode(Int, String)
    case missingToken
    case missingData
    case transportError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case let .invalidStatusCode(code, message):
            return message.isEmpty ? "Request failed with status \(code)" : message
        case .missingToken:
            return "Missing access token"
        case .missingData:
            return "Missing response data"
        case let .transportError(message):
            return message
        }
    }

    var isUnauthorized: Bool {
        if case let .invalidStatusCode(code, _) = self {
            return code == 401
        }
        return false
    }
}

final class APIClient {
    static let shared = APIClient()

    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(urlSession: URLSession? = nil) {
        self.urlSession = urlSession ?? Self.makeDefaultSession()
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
        self.encoder = JSONEncoder()
    }

    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        bearerToken: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> T {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        applyDefaultHeaders(to: &request, bearerToken: bearerToken)
        return try await execute(request)
    }

    func post<T: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        bearerToken: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        applyDefaultHeaders(to: &request, bearerToken: bearerToken)
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    func postJSON<T: Decodable>(
        path: String,
        jsonObject: [String: Any],
        bearerToken: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        applyDefaultHeaders(to: &request, bearerToken: bearerToken)
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        return try await execute(request)
    }

    func uploadImage(
        data: Data,
        fileName: String,
        mimeType: String = "image/jpeg",
        bearerToken: String,
        timeoutInterval: TimeInterval? = 180
    ) async throws -> UploadImageResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = try buildURL(path: "upload-image")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        applyDefaultHeaders(
            to: &request,
            bearerToken: bearerToken,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        request.httpBody = createMultipartBody(
            boundary: boundary,
            fileData: data,
            fileName: fileName,
            mimeType: mimeType
        )
        return try await execute(request)
    }

    func uploadVideo(
        data: Data,
        fileName: String,
        mimeType: String = "video/mp4",
        bearerToken: String,
        timeoutInterval: TimeInterval? = 180
    ) async throws -> UploadVideoResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = try buildURL(path: "upload-video")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        applyDefaultHeaders(
            to: &request,
            bearerToken: bearerToken,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        request.httpBody = createMultipartBody(
            boundary: boundary,
            fileData: data,
            fileName: fileName,
            mimeType: mimeType
        )
        return try await execute(request)
    }

    func postSupabaseAuth<T: Decodable, Body: Encodable>(body: Body) async throws -> T {
        var components = URLComponents(url: APIConfig.supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components?.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(APIConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    private func buildURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: APIConfig.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        return url
    }

    private func applyDefaultHeaders(
        to request: inout URLRequest,
        bearerToken: String?,
        contentType: String = "application/json"
    ) {
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(APIConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken ?? APIConfig.anonKey)", forHTTPHeaderField: "Authorization")
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await executeData(request)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T {
                return empty
            }
            throw error
        }
    }

    private func executeData(_ request: URLRequest) async throws -> Data {
        let maxAttempts = shouldRetryNetworkErrors(for: request) ? 3 : 1
        var attempt = 0

        while true {
            attempt += 1
            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    let message = parseErrorMessage(from: data)
                    throw APIError.invalidStatusCode(httpResponse.statusCode, message)
                }

                return data
            } catch let error as URLError {
                if shouldRetry(request: request, error: error, attempt: attempt, maxAttempts: maxAttempts) {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    continue
                }
                throw mapTransportError(error, for: request)
            }
        }
    }


    private func shouldRetryNetworkErrors(for request: URLRequest) -> Bool {
        request.url?.lastPathComponent == "apple-iap-verify"
    }

    private func shouldRetry(request: URLRequest, error: URLError, attempt: Int, maxAttempts: Int) -> Bool {
        guard shouldRetryNetworkErrors(for: request) else { return false }
        guard attempt < maxAttempts else { return false }

        switch error.code {
        case .networkConnectionLost, .timedOut, .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }


    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 240
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.httpShouldUsePipelining = false
        return URLSession(configuration: configuration)
    }

    private func mapTransportError(_ error: URLError, for request: URLRequest) -> APIError {
        let path = request.url?.lastPathComponent ?? "request"
        let isTaskCreationRequest = request.httpMethod == "POST" && ["image-to-image", "image-to-video", "image-to-dongzuo-video", "text-to-image", "text-to-video", "video-face-swap"].contains(path)

        switch error.code {
        case .networkConnectionLost:
            if isTaskCreationRequest {
                return .transportError("The network connection was interrupted while submitting the task. Please check your network. If credits were already deducted, open Profile and confirm whether the task was created before retrying.")
            }
            return .transportError("The network connection was lost. Please try again.")
        case .timedOut:
            if isTaskCreationRequest {
                return .transportError("Submitting the task took too long. Please check your network and try again. If credits were already deducted, open Profile before retrying.")
            }
            return .transportError("The request timed out. Please try again.")
        case .notConnectedToInternet:
            return .transportError("No internet connection. Please check your network and try again.")
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return .transportError("Unable to connect to the server right now. Please try again in a moment.")
        case .cancelled:
            return .transportError("The request was cancelled.")
        default:
            return .transportError(error.localizedDescription)
        }
    }

    private func parseErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
            if let error = json["error"] as? String, !error.isEmpty {
                return error
            }
            if let errorMessage = json["error_message"] as? String, !errorMessage.isEmpty {
                return errorMessage
            }
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return "" }

        let lowered = raw.lowercased()
        if lowered.contains("<html") || lowered.contains("<head>") || lowered.contains("<body>") {
            return "Server error. Please try again."
        }
        if lowered.contains("internal server error") {
            return "Server error. Please try again."
        }

        return raw
    }

    private func createMultipartBody(
        boundary: String,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(fileData)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)

        return body
    }
}

private struct EmptyResponse: Decodable {
    init?() {}
}
