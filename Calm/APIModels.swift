import Foundation

struct AnonymousLoginResponse: Decodable {
    let user: APIUser
    let session: APISession?
    let message: String?
    let requiresRefreshToken: Bool?

    enum CodingKeys: String, CodingKey {
        case user
        case session
        case message
        case requiresRefreshToken = "requires_refresh_token"
    }
}

struct APIUser: Decodable {
    let id: String
    let isAnonymous: Bool
    let appID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case isAnonymous = "is_anonymous"
        case appID = "app_id"
    }
}

struct APISession: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct RefreshSessionResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: APIUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct ReviewLoginResponse: Decodable {
    let user: ReviewLoginUser
    let session: APISession
    let message: String?
}

struct ReviewLoginUser: Decodable {
    let id: String
    let isReviewUser: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case isReviewUser = "is_review_user"
    }
}

struct UserStatus: Codable {
    let subscriptionStatus: String
    let subscriptionExpireAt: String?
    let planType: String?
    let creditsBalance: Int
    let isAnonymous: Bool

    enum CodingKeys: String, CodingKey {
        case subscriptionStatus = "subscription_status"
        case subscriptionExpireAt = "subscription_expire_at"
        case planType = "plan_type"
        case creditsBalance = "credits_balance"
        case isAnonymous = "is_anonymous"
    }

    var isSubscriptionActive: Bool {
        subscriptionStatus == "active"
    }
}

struct FeatureConfigsResponse: Decodable {
    let sections: [RemoteFeatureSection]
    let pagination: FeaturePagination?
    let version: String?
}

struct FeaturePagination: Decodable {
    let limit: Int?
    let hasNext: Bool
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case limit
        case hasNext = "has_next"
        case nextCursor = "next_cursor"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        limit = container.decodeLossyIntIfPresent(forKey: .limit)
        hasNext = (try? container.decode(Bool.self, forKey: .hasNext)) ?? false
        nextCursor = container.decodeLossyStringIfPresent(forKey: .nextCursor)
    }
}

struct RemoteFeatureSection: Decodable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String?
    let subtitle: String?
    let layout: String
    let menu: String?
    let sortOrder: Int?
    let items: [RemoteFeatureItem]

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case subtitle
        case layout
        case menu
        case sortOrder = "sort_order"
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyString(forKey: .id) ?? UUID().uuidString
        type = (try? container.decode(String.self, forKey: .type)) ?? "section"
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try? container.decodeIfPresent(String.self, forKey: .subtitle)
        layout = (try? container.decode(String.self, forKey: .layout)) ?? "horizontal_scroll"
        menu = try? container.decodeIfPresent(String.self, forKey: .menu)
        sortOrder = container.decodeLossyIntIfPresent(forKey: .sortOrder)
        items = (try? container.decode([RemoteFeatureItem].self, forKey: .items)) ?? []
    }

    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return subtitle
        }
        return "Featured"
    }

    var displaySubtitle: String? {
        guard let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return subtitle
    }
}

struct RemoteFeatureItem: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let modelType: String?
    let modelID: String?
    let iconURLString: String?
    let coverImageURLString: String?
    let coverVideoURLString: String?
    let coverVideoThumbnailURLString: String?
    let previewStyle: String?
    let isAd: Bool
    let adIOSURLString: String?
    let badge: String?
    let cardType: String?
    let textMode: String?
    let textImageURLString: String?
    let sortOrder: Int?
    let requiresPreview: Bool?
    let estimatedCredits: Int?
    let scene: String?
    let template: String?
    let promptTemplate: String?
    let enableImageMerge: Bool?
    let previewConfig: RemotePreviewConfig?
    let materialRequirements: [RemoteMaterialRequirement]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case modelType = "model_type"
        case modelID = "model_id"
        case iconURLString = "icon_url"
        case coverImageURLString = "cover_image_url"
        case coverVideoURLString = "cover_video"
        case coverVideoThumbnailURLString = "cover_video_thumbnail"
        case previewStyle = "preview_style"
        case isAd = "is_ad"
        case adIOSURLString = "ad_ios_url"
        case badge
        case cardType = "card_type"
        case textMode = "text_mode"
        case textImageURLString = "text_image_url"
        case sortOrder = "sort_order"
        case requiresPreview = "requires_preview"
        case estimatedCredits = "estimated_credits"
        case scene
        case template
        case promptTemplate = "prompt_template"
        case enableImageMerge = "enable_image_merge"
        case previewConfig = "preview_config"
        case materialRequirements = "material_requirements"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyString(forKey: .id) ?? UUID().uuidString
        title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled"
        subtitle = try? container.decodeIfPresent(String.self, forKey: .subtitle)
        modelType = try? container.decodeIfPresent(String.self, forKey: .modelType)
        modelID = try? container.decodeIfPresent(String.self, forKey: .modelID)
        iconURLString = try? container.decodeIfPresent(String.self, forKey: .iconURLString)
        coverImageURLString = try? container.decodeIfPresent(String.self, forKey: .coverImageURLString)
        coverVideoURLString = try? container.decodeIfPresent(String.self, forKey: .coverVideoURLString)
        coverVideoThumbnailURLString = try? container.decodeIfPresent(String.self, forKey: .coverVideoThumbnailURLString)
        previewStyle = try? container.decodeIfPresent(String.self, forKey: .previewStyle)
        isAd = (try? container.decode(Bool.self, forKey: .isAd)) ?? false
        adIOSURLString = try? container.decodeIfPresent(String.self, forKey: .adIOSURLString)
        badge = try? container.decodeIfPresent(String.self, forKey: .badge)
        cardType = try? container.decodeIfPresent(String.self, forKey: .cardType)
        textMode = try? container.decodeIfPresent(String.self, forKey: .textMode)
        textImageURLString = try? container.decodeIfPresent(String.self, forKey: .textImageURLString)
        sortOrder = container.decodeLossyIntIfPresent(forKey: .sortOrder)
        requiresPreview = try? container.decodeIfPresent(Bool.self, forKey: .requiresPreview)
        estimatedCredits = container.decodeLossyIntIfPresent(forKey: .estimatedCredits)
        scene = try? container.decodeIfPresent(String.self, forKey: .scene)
        template = try? container.decodeIfPresent(String.self, forKey: .template)
        promptTemplate = try? container.decodeIfPresent(String.self, forKey: .promptTemplate)
        enableImageMerge = try? container.decodeIfPresent(Bool.self, forKey: .enableImageMerge)
        previewConfig = try? container.decodeIfPresent(RemotePreviewConfig.self, forKey: .previewConfig)
        materialRequirements = (try? container.decode([RemoteMaterialRequirement].self, forKey: .materialRequirements)) ?? []
    }

    var iconURL: URL? {
        URL(string: iconURLString ?? "")
    }

    var effectiveCoverURL: URL? {
        let primary = coverImageURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primary.isEmpty, let url = URL(string: primary) {
            return url
        }

        let fallback = coverVideoThumbnailURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fallback.isEmpty, let url = URL(string: fallback) {
            return url
        }

        return nil
    }

    var coverVideoURL: URL? {
        let value = coverVideoURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }

    var adIOSURL: URL? {
        URL(string: adIOSURLString ?? "")
    }

    var displaySubtitle: String {
        guard let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return previewConfig?.description ?? "Create with AI in one tap"
        }
        return subtitle
    }

    var displayBadge: String? {
        guard let badge, !badge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return badge
    }

    var creditsText: String {
        "\(estimatedCredits ?? 0) Coins"
    }
}

struct RemotePreviewConfig: Codable, Hashable {
    let beforeImageURLString: String?
    let afterImageURLString: String?
    let title: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case beforeImageURLString = "before_image_url"
        case afterImageURLString = "after_image_url"
        case title
        case description
    }
}

struct RemoteMaterialRequirement: Codable, Hashable {
    let id: String?
    let type: String?
    let label: String?
    let description: String?
    let required: Bool?
}

struct TaskListResponse: Decodable {
    let tasks: [UserTask]
    let total: Int?
    let limit: Int?
    let offset: Int?
}

struct UserTask: Decodable, Identifiable, Hashable {
    let id: String
    let scene: String?
    let status: String?
    let outputURLString: String?
    let creditsUsed: Int?
    let createdAt: String?
    let sectionMenu: String?

    enum CodingKeys: String, CodingKey {
        case id
        case scene
        case status
        case outputURLString = "output_url"
        case creditsUsed = "credits_used"
        case createdAt = "created_at"
        case sectionMenu = "section_menu"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyString(forKey: .id) ?? UUID().uuidString
        scene = try? container.decodeIfPresent(String.self, forKey: .scene)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        outputURLString = try? container.decodeIfPresent(String.self, forKey: .outputURLString)
        creditsUsed = container.decodeLossyIntIfPresent(forKey: .creditsUsed)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        sectionMenu = try? container.decodeIfPresent(String.self, forKey: .sectionMenu)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(Int(doubleValue))
        }
        return nil
    }

    func decodeLossyStringIfPresent(forKey key: Key) -> String? {
        decodeLossyString(forKey: key)
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
