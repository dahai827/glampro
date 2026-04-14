import Foundation

private struct EmptyRequestBody: Encodable {}

struct DailyCheckinStatusResponse: Decodable {
    let success: Bool
    let appID: String?
    let today: String?
    let timezone: String?
    let cycleDays: Int
    let isActive: Bool
    let signedToday: Bool
    let claimableDay: Int?
    let claimableCredits: Int
    let nextClaimableDay: Int?
    let currentStreakDay: Int
    let resetFromInterruption: Bool
    let rewards: [DailyCheckinReward]

    enum CodingKeys: String, CodingKey {
        case success
        case appID = "app_id"
        case today
        case timezone
        case cycleDays = "cycle_days"
        case isActive = "is_active"
        case signedToday = "signed_today"
        case claimableDay = "claimable_day"
        case claimableCredits = "claimable_credits"
        case nextClaimableDay = "next_claimable_day"
        case currentStreakDay = "current_streak_day"
        case resetFromInterruption = "reset_from_interruption"
        case rewards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        appID = try? container.decodeIfPresent(String.self, forKey: .appID)
        today = try? container.decodeIfPresent(String.self, forKey: .today)
        timezone = try? container.decodeIfPresent(String.self, forKey: .timezone)
        cycleDays = container.decodeLossyInt(forKey: .cycleDays) ?? 7
        isActive = (try? container.decode(Bool.self, forKey: .isActive)) ?? false
        signedToday = (try? container.decode(Bool.self, forKey: .signedToday)) ?? false
        claimableDay = container.decodeLossyInt(forKey: .claimableDay)
        claimableCredits = container.decodeLossyInt(forKey: .claimableCredits) ?? 0
        nextClaimableDay = container.decodeLossyInt(forKey: .nextClaimableDay)
        currentStreakDay = container.decodeLossyInt(forKey: .currentStreakDay) ?? 0
        resetFromInterruption = (try? container.decode(Bool.self, forKey: .resetFromInterruption)) ?? false
        rewards = (try? container.decode([DailyCheckinReward].self, forKey: .rewards)) ?? []
    }
}

struct DailyCheckinReward: Decodable, Identifiable {
    let day: Int
    let credits: Int
    let status: String

    var id: Int { day }

    enum CodingKeys: String, CodingKey {
        case day
        case credits
        case status
    }

    init(day: Int, credits: Int, status: String) {
        self.day = day
        self.credits = credits
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = container.decodeLossyInt(forKey: .day) ?? 0
        credits = container.decodeLossyInt(forKey: .credits) ?? 0
        status = (try? container.decode(String.self, forKey: .status)) ?? "upcoming"
    }
}

struct DailyCheckinSignResponse: Decodable {
    let success: Bool
    let appID: String?
    let alreadySignedToday: Bool
    let checkinDate: String?
    let dayNo: Int?
    let creditsGranted: Int
    let creditsBalance: Int?
    let nextClaimableDay: Int?
    let resetFromInterruption: Bool
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case appID = "app_id"
        case alreadySignedToday = "already_signed_today"
        case checkinDate = "checkin_date"
        case dayNo = "day_no"
        case creditsGranted = "credits_granted"
        case creditsBalance = "credits_balance"
        case nextClaimableDay = "next_claimable_day"
        case resetFromInterruption = "reset_from_interruption"
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        appID = try? container.decodeIfPresent(String.self, forKey: .appID)
        alreadySignedToday = (try? container.decode(Bool.self, forKey: .alreadySignedToday)) ?? false
        checkinDate = try? container.decodeIfPresent(String.self, forKey: .checkinDate)
        dayNo = container.decodeLossyInt(forKey: .dayNo)
        creditsGranted = container.decodeLossyInt(forKey: .creditsGranted) ?? 0
        creditsBalance = container.decodeLossyInt(forKey: .creditsBalance)
        nextClaimableDay = container.decodeLossyInt(forKey: .nextClaimableDay)
        resetFromInterruption = (try? container.decode(Bool.self, forKey: .resetFromInterruption)) ?? false
        message = try? container.decodeIfPresent(String.self, forKey: .message)
    }
}

@MainActor
final class DailyCheckinStore: ObservableObject {
    static let shared = DailyCheckinStore()

    @Published private(set) var status: DailyCheckinStatusResponse?
    @Published private(set) var isLoadingStatus = false
    @Published private(set) var isSigning = false
    @Published private(set) var errorMessage: String?

    private let apiClient: APIClient
    private var lastStatusFetchAt: Date?
    private var lastFetchedDateKey: String?

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var canClaimToday: Bool {
        guard let status else { return false }
        guard status.success, status.isActive else { return false }
        guard !status.signedToday else { return false }
        return status.claimableDay != nil && status.claimableCredits > 0
    }

    func refreshStatus(sessionManager: SessionManager, force: Bool = false) async {
        if !force, shouldSkipRefresh() {
            return
        }

        let shouldShowLoading = status == nil
        if shouldShowLoading {
            isLoadingStatus = true
        }
        defer {
            if shouldShowLoading {
                isLoadingStatus = false
            }
        }

        do {
            let response: DailyCheckinStatusResponse = try await sessionManager.performAuthenticatedRequest { token in
                try await self.apiClient.get(path: "daily-checkin-status", bearerToken: token)
            }

            status = response
            errorMessage = nil
            lastStatusFetchAt = Date()
            lastFetchedDateKey = response.today
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signToday(sessionManager: SessionManager) async -> DailyCheckinSignResponse? {
        guard !isSigning else { return nil }
        isSigning = true
        defer { isSigning = false }

        do {
            let response: DailyCheckinSignResponse = try await sessionManager.performAuthenticatedRequest { token in
                try await self.apiClient.post(path: "daily-checkin-sign", body: EmptyRequestBody(), bearerToken: token)
            }

            if response.success {
                let granted = max(response.creditsGranted, 0)
                let newBalance = response.creditsBalance ?? (sessionManager.creditsBalance + granted)
                sessionManager.applyCreditsBalance(newBalance)
            }

            await refreshStatus(sessionManager: sessionManager, force: true)
            errorMessage = nil
            return response
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func shouldSkipRefresh() -> Bool {
        if let lastStatusFetchAt, Date().timeIntervalSince(lastStatusFetchAt) < 20 {
            return true
        }
        if let status, status.signedToday, let today = status.today, today == lastFetchedDateKey {
            return true
        }
        return false
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyInt(forKey key: Key) -> Int? {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            return Int(stringValue)
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }
}
