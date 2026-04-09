import CoreGraphics
import Foundation

struct TrendCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let paletteIndex: Int
}

struct FeatureCardModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let paletteIndex: Int
}

struct FeedCardModel: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let likes: Int
    let height: CGFloat
    let paletteIndex: Int
}

struct ShotCardModel: Identifiable {
    let id = UUID()
    let height: CGFloat
    let paletteIndex: Int
}

struct HomeCollectionCardModel: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let likesText: String
    let height: CGFloat
    let paletteIndex: Int
    let isNew: Bool
    let showsFeaturedMark: Bool
}

enum FeedCategory: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case nearby = "Nearby"
    case dailyTop = "Daily Top"

    var id: String { rawValue }
}

enum ProfileSegment: String, CaseIterable, Identifiable {
    case drafts = "Drafts"
    case posts = "History"
    case liked = "Liked"
    case saved = "Saved"

    var id: String { rawValue }
}

enum PurchasePackage: String, CaseIterable, Identifiable {
    case large
    case medium
    case small

    var id: String { rawValue }

    var title: String {
        switch self {
        case .large: return "20000 coins pack"
        case .medium: return "5000 coins pack"
        case .small: return "2000 coins pack"
        }
    }

    var price: String {
        switch self {
        case .large: return "$125"
        case .medium: return "$49.99"
        case .small: return "$14.99"
        }
    }

    var originalPrice: String {
        switch self {
        case .large: return "$251"
        case .medium: return "$99"
        case .small: return "$29.98"
        }
    }
}

enum MockData {
    static let trends: [TrendCard] = [
        TrendCard(title: "Emelia", subtitle: "Sky dancer", paletteIndex: 0),
        TrendCard(title: "Golden Muse", subtitle: "Soft portrait", paletteIndex: 1),
        TrendCard(title: "Royal Glow", subtitle: "Studio lighting", paletteIndex: 4),
        TrendCard(title: "Street Echo", subtitle: "Urban fashion", paletteIndex: 2)
    ]

    static let spotlight: [TrendCard] = [
        TrendCard(title: "Retro Motion", subtitle: "80s glow", paletteIndex: 6),
        TrendCard(title: "Soft Drama", subtitle: "Night edit", paletteIndex: 7),
        TrendCard(title: "Pet Lens", subtitle: "Cute moment", paletteIndex: 5)
    ]

    static let newDrops: [TrendCard] = [
        TrendCard(title: "Aura Edit", subtitle: "Fresh this week", paletteIndex: 7),
        TrendCard(title: "Gloss Mode", subtitle: "Trending now", paletteIndex: 0),
        TrendCard(title: "Studio Pop", subtitle: "New arrival", paletteIndex: 6),
        TrendCard(title: "Velvet Glow", subtitle: "Editor pick", paletteIndex: 1)
    ]

    static let newHighlights: [TrendCard] = [
        TrendCard(title: "Street Bloom", subtitle: "Style update", paletteIndex: 4),
        TrendCard(title: "Soft Focus", subtitle: "Popular drop", paletteIndex: 2),
        TrendCard(title: "Dream Frame", subtitle: "Trending pack", paletteIndex: 5)
    ]

    static let featureCards: [FeatureCardModel] = [
        FeatureCardModel(title: "AI Chat", subtitle: "Create anything you imagine", symbol: "sparkles", paletteIndex: 7),
        FeatureCardModel(title: "Custom Styles", subtitle: "Animate and edit photos", symbol: "paintbrush.pointed.fill", paletteIndex: 2),
        FeatureCardModel(title: "Shots", subtitle: "New look every day", symbol: "calendar", paletteIndex: 5),
        FeatureCardModel(title: "Motion swap", subtitle: "Go viral in one tap", symbol: "figure.run", paletteIndex: 4),
        FeatureCardModel(title: "Group Shots", subtitle: "Couple & friends moments", symbol: "calendar.badge.plus", paletteIndex: 6),
        FeatureCardModel(title: "Daily Reels", subtitle: "Make lifestyle videos daily", symbol: "person.2.crop.square.stack.fill", paletteIndex: 1),
        FeatureCardModel(title: "Product Shots", subtitle: "Boost your sales in one tap", symbol: "dollarsign.circle.fill", paletteIndex: 5),
        FeatureCardModel(title: "Product Ads", subtitle: "Create AI product video ads", symbol: "shippingbox.fill", paletteIndex: 6),
        FeatureCardModel(title: "Lipsync", subtitle: "Make your photo talk", symbol: "mic.fill", paletteIndex: 1),
        FeatureCardModel(title: "Man's World", subtitle: "Try masculine looks", symbol: "figure.stand", paletteIndex: 4),
        FeatureCardModel(title: "Polar Camera", subtitle: "Instant retro-style photos", symbol: "photo.stack.fill", paletteIndex: 3),
        FeatureCardModel(title: "The Inside Out", subtitle: "See your other side", symbol: "camera.filters", paletteIndex: 7),
        FeatureCardModel(title: "Makeup", subtitle: "From natural glow to glam", symbol: "paintbrush.pointed.fill", paletteIndex: 0),
        FeatureCardModel(title: "Post To Feed", subtitle: "Share your creations", symbol: "rectangle.stack.badge.person.crop.fill", paletteIndex: 2)
    ]

    static let shotCategories: [String] = ["New", "Easter", "Trending", "Girl Boss", "Profile"]

    static let shotCards: [ShotCardModel] = [
        ShotCardModel(height: 272, paletteIndex: 6),
        ShotCardModel(height: 238, paletteIndex: 5),
        ShotCardModel(height: 194, paletteIndex: 2),
        ShotCardModel(height: 226, paletteIndex: 1),
        ShotCardModel(height: 208, paletteIndex: 0),
        ShotCardModel(height: 252, paletteIndex: 7)
    ]

    static let motionCards: [ShotCardModel] = [
        ShotCardModel(height: 256, paletteIndex: 2),
        ShotCardModel(height: 220, paletteIndex: 6),
        ShotCardModel(height: 212, paletteIndex: 4),
        ShotCardModel(height: 244, paletteIndex: 7),
        ShotCardModel(height: 204, paletteIndex: 3),
        ShotCardModel(height: 230, paletteIndex: 1)
    ]

    static let viralTrendCollectionCards: [HomeCollectionCardModel] = [
        HomeCollectionCardModel(title: "The person is always looking at the camera, eye contact...", author: "EmeliaBeer", likesText: "99K", height: 272, paletteIndex: 0, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Create two vertical photo booth-style strips on a dark room wall", author: "DeliaRau", likesText: "131K", height: 236, paletteIndex: 6, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Create a photorealistic smartphone selfie with two characters", author: "NoaMilan", likesText: "82K", height: 248, paletteIndex: 1, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "A realistic, dark, nighttime selfie of a character in a bedroom", author: "ViviHart", likesText: "76K", height: 266, paletteIndex: 7, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Golden hour portrait with soft breeze and dreamy motion", author: "LunaVale", likesText: "58K", height: 258, paletteIndex: 4, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Urban mirror pose with editorial lighting and glossy skin", author: "SeraBlue", likesText: "104K", height: 284, paletteIndex: 2, isNew: false, showsFeaturedMark: true)
    ]

    static let spotlightCollectionCards: [HomeCollectionCardModel] = [
        HomeCollectionCardModel(title: "Soft glam portrait with premium studio lighting", author: "MiraCole", likesText: "64K", height: 282, paletteIndex: 5, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Luxury hallway editorial frame with bold styling", author: "KoraLane", likesText: "48K", height: 238, paletteIndex: 3, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Night street portrait with cinematic purple backlight", author: "RaeVoss", likesText: "73K", height: 264, paletteIndex: 7, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Moody flash selfie with polished magazine cover vibes", author: "LeniFox", likesText: "88K", height: 298, paletteIndex: 1, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Classic monochrome booth strip with intimate framing", author: "AylaMae", likesText: "55K", height: 246, paletteIndex: 6, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Warm peach portrait for premium beauty campaigns", author: "DaniRue", likesText: "67K", height: 276, paletteIndex: 0, isNew: false, showsFeaturedMark: true)
    ]

    static let freshPickCollectionCards: [HomeCollectionCardModel] = [
        HomeCollectionCardModel(title: "Fresh selfie concept with cozy room lighting and depth", author: "AriSage", likesText: "42K", height: 270, paletteIndex: 1, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Bright fashion crop with airy skin retouch and glow", author: "NinaPearl", likesText: "51K", height: 232, paletteIndex: 4, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "New release couple pose for social post covers", author: "IvyLo", likesText: "39K", height: 256, paletteIndex: 6, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Bathroom mirror capture with trendy flash feel", author: "MoeJade", likesText: "61K", height: 292, paletteIndex: 2, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Peach-toned portrait with smooth makeup detail", author: "SaraMint", likesText: "44K", height: 244, paletteIndex: 0, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Street fit photo set made for fast profile upgrades", author: "KikoAsh", likesText: "57K", height: 280, paletteIndex: 5, isNew: true, showsFeaturedMark: true)
    ]

    static let editorsChoiceCollectionCards: [HomeCollectionCardModel] = [
        HomeCollectionCardModel(title: "Editor's favorite soft shadow portrait with luxury tone", author: "EmaJune", likesText: "91K", height: 286, paletteIndex: 7, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Signature beauty shot with sleek contrast and polish", author: "RinVale", likesText: "68K", height: 240, paletteIndex: 3, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Curated date-night portrait with dramatic room lighting", author: "LolaSkye", likesText: "72K", height: 258, paletteIndex: 1, isNew: true, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Editorial feed cover for creator profiles and launches", author: "NoraWest", likesText: "86K", height: 300, paletteIndex: 6, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "Muted retro booth collage with timeless framing", author: "KaraMoon", likesText: "49K", height: 248, paletteIndex: 5, isNew: false, showsFeaturedMark: true),
        HomeCollectionCardModel(title: "High-impact portrait tuned for viral beauty edits", author: "MeliStar", likesText: "95K", height: 278, paletteIndex: 2, isNew: true, showsFeaturedMark: true)
    ]

    static let feedCards: [FeedCardModel] = [
        FeedCardModel(title: "Girl walks like a model Camera slowly move away, showing...", author: "User01ffc84d", likes: 5, height: 309, paletteIndex: 2),
        FeedCardModel(title: "Animate", author: "gonzal422", likes: 17, height: 309, paletteIndex: 5),
        FeedCardModel(title: "Baby shark style portrait", author: "calmhero", likes: 11, height: 281, paletteIndex: 0),
        FeedCardModel(title: "Soft bedroom collage", author: "urbanfilter", likes: 9, height: 281, paletteIndex: 1),
        FeedCardModel(title: "Neon beauty frame", author: "studiodream", likes: 23, height: 309, paletteIndex: 7),
        FeedCardModel(title: "Vintage family revive", author: "memorylab", likes: 14, height: 281, paletteIndex: 6)
    ]
}
