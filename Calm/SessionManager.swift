import Foundation
import UIKit

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var userStatus: UserStatus?
    @Published private(set) var creditsBalance: Int = 0
    @Published private(set) var userID: String?
    @Published private(set) var accessToken: String?
    @Published private(set) var refreshToken: String?
    @Published private(set) var isPreparingSession = false
    @Published private(set) var didFinishBootstrapAttempt = false
    @Published private(set) var lastErrorMessage: String?

    private let apiClient: APIClient
    private let keychain: KeychainManager
    private let userDefaults: UserDefaults

    private let accessTokenKey = "\(APIConfig.appID).accessToken"
    private let refreshTokenKey = "\(APIConfig.appID).refreshToken"
    private let userIDKey = "\(APIConfig.appID).userID"
    private let userStatusKey = "\(APIConfig.appID).userStatus"

    init(
        apiClient: APIClient = .shared,
        keychain: KeychainManager = KeychainManager(),
        userDefaults: UserDefaults = .standard
    ) {
        self.apiClient = apiClient
        self.keychain = keychain
        self.userDefaults = userDefaults
        loadPersistedState()
    }

    var isPro: Bool {
        userStatus?.isSubscriptionActive ?? false
    }

    var displayUserName: String {
        guard let userID, !userID.isEmpty else {
            return "User"
        }
        let compact = userID.replacingOccurrences(of: "-", with: "")
        return "User\(compact.prefix(8))"
    }

    func bootstrapIfNeeded() async throws {
        guard !isPreparingSession else { return }
        isPreparingSession = true
        didFinishBootstrapAttempt = false
        defer {
            isPreparingSession = false
            didFinishBootstrapAttempt = true
        }

        do {
            try await ensureAuthenticatedSession()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func refreshUserStatus() async {
        do {
            _ = try await performAuthenticatedRequest { token in
                try await self.fetchUserStatus(using: token)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func reviewLogin() async throws {
        struct RequestBody: Encodable {
            let app_id: String
        }

        let response: ReviewLoginResponse = try await apiClient.post(
            path: "review-login",
            body: RequestBody(app_id: APIConfig.appID),
            bearerToken: APIConfig.anonKey
        )

        userID = response.user.id
        userDefaults.set(response.user.id, forKey: userIDKey)
        saveSession(accessToken: response.session.accessToken, refreshToken: response.session.refreshToken)
        try await fetchUserStatus(using: response.session.accessToken)
        lastErrorMessage = nil
    }

    func applyUserStatus(_ status: UserStatus) {
        userStatus = status
        creditsBalance = status.creditsBalance
        persistUserStatus(status)
    }

    func updateUserStatusFromCreditPurchase(credits newBalance: Int) {
        creditsBalance = newBalance
        if let userStatus {
            let updatedStatus = UserStatus(
                subscriptionStatus: userStatus.subscriptionStatus,
                subscriptionExpireAt: userStatus.subscriptionExpireAt,
                planType: userStatus.planType,
                creditsBalance: newBalance,
                isAnonymous: userStatus.isAnonymous
            )
            self.userStatus = updatedStatus
            persistUserStatus(updatedStatus)
        }
    }

    func applyCreditsBalance(_ newBalance: Int) {
        creditsBalance = newBalance
        if let userStatus {
            let updatedStatus = UserStatus(
                subscriptionStatus: userStatus.subscriptionStatus,
                subscriptionExpireAt: userStatus.subscriptionExpireAt,
                planType: userStatus.planType,
                creditsBalance: newBalance,
                isAnonymous: userStatus.isAnonymous
            )
            self.userStatus = updatedStatus
            persistUserStatus(updatedStatus)
        }
    }

    func performAuthenticatedRequest<T>(_ operation: @escaping (String) async throws -> T) async throws -> T {
        if accessToken == nil {
            try await ensureAuthenticatedSession()
        }

        guard let accessToken else {
            throw APIError.missingToken
        }

        do {
            return try await operation(accessToken)
        } catch let error as APIError where error.isUnauthorized {
            try await refreshSessionOrRelogin()
            guard let refreshedToken = self.accessToken else {
                throw APIError.missingToken
            }
            return try await operation(refreshedToken)
        }
    }

    private func ensureAuthenticatedSession() async throws {
        if accessToken == nil {
            if refreshToken != nil {
                do {
                    try await refreshSession()
                } catch {
                    try await anonymousLogin()
                }
            } else {
                try await anonymousLogin()
            }
        }

        if let accessToken {
            do {
                try await fetchUserStatus(using: accessToken)
            } catch let error as APIError where error.isUnauthorized {
                try await refreshSessionOrRelogin()
                if let refreshedToken = self.accessToken {
                    try await fetchUserStatus(using: refreshedToken)
                }
            }
        }
    }

    private func refreshSessionOrRelogin() async throws {
        do {
            try await refreshSession()
        } catch {
            try await anonymousLogin()
        }
    }

    private func anonymousLogin() async throws {
        struct RequestBody: Encodable {
            let app_id: String
            let country: String?
            let channel: String?
            let platform: String
            let idfv: String?
        }

        let body = RequestBody(
            app_id: APIConfig.appID,
            country: Locale.current.regionCode,
            channel: "organic",
            platform: "ios",
            idfv: UIDevice.current.identifierForVendor?.uuidString
        )

        let response: AnonymousLoginResponse = try await apiClient.post(
            path: "anonymous-login",
            body: body,
            bearerToken: APIConfig.anonKey
        )

        userID = response.user.id
        userDefaults.set(response.user.id, forKey: userIDKey)

        guard let session = response.session else {
            throw APIError.missingData
        }

        saveSession(accessToken: session.accessToken, refreshToken: session.refreshToken)
    }

    private func refreshSession() async throws {
        struct RefreshBody: Encodable {
            let refresh_token: String
        }

        guard let refreshToken else {
            throw APIError.missingToken
        }

        let response: RefreshSessionResponse = try await apiClient.postSupabaseAuth(body: RefreshBody(refresh_token: refreshToken))
        saveSession(accessToken: response.accessToken, refreshToken: response.refreshToken)

        if let refreshedUserID = response.user?.id {
            userID = refreshedUserID
            userDefaults.set(refreshedUserID, forKey: userIDKey)
        }
    }

    private func fetchUserStatus(using token: String) async throws {
        let status: UserStatus = try await apiClient.get(path: "user-status", bearerToken: token)
        userStatus = status
        creditsBalance = status.creditsBalance
        persistUserStatus(status)
    }

    private func saveSession(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        keychain.set(accessToken, for: accessTokenKey)
        keychain.set(refreshToken, for: refreshTokenKey)
    }

    private func persistUserStatus(_ status: UserStatus) {
        if let data = try? JSONEncoder().encode(status) {
            userDefaults.set(data, forKey: userStatusKey)
        }
    }

    private func loadPersistedState() {
        accessToken = keychain.get(accessTokenKey)
        refreshToken = keychain.get(refreshTokenKey)
        userID = userDefaults.string(forKey: userIDKey)

        if let data = userDefaults.data(forKey: userStatusKey),
           let status = try? JSONDecoder().decode(UserStatus.self, from: data) {
            userStatus = status
            creditsBalance = status.creditsBalance
        }
    }
}
