import SwiftUI

enum GlamProTheme {
    static let background = Color(hex: "111111")
    static let elevated = Color(hex: "1B1B1D")
    static let surface = Color(hex: "262628")
    static let stroke = Color.white.opacity(0.08)
    static let secondaryText = Color.white.opacity(0.68)
    static let tertiaryText = Color.white.opacity(0.42)
    static let pink = Color(hex: "FF3E81")
    static let orange = Color(hex: "FF9D5C")
    static let yellow = Color(hex: "F6C34E")
    static let blue = Color(hex: "3294FF")
    static let indigo = Color(hex: "8C78FF")
    static let purple = Color(hex: "BC8CFF")
    static let sky = Color(hex: "3F8DDC")
    static let ocean = Color(hex: "1F5E96")
    static let shadow = Color.black.opacity(0.28)

    static let brandGradient = LinearGradient(
        colors: [Color(hex: "FF7B72"), Color(hex: "FF57A9"), Color(hex: "8B6DFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [pink, orange],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let goldGradient = LinearGradient(
        colors: [Color(hex: "D59C19"), Color(hex: "816104")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let creditsBackground = LinearGradient(
        colors: [Color(hex: "4B94D8"), Color(hex: "2A659C")],
        startPoint: .top,
        endPoint: .bottom
    )

    static func cardGradient(_ index: Int) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(hex: "FF9AA0"), Color(hex: "FFB56A")],
            [Color(hex: "F4A4D7"), Color(hex: "C78BFF")],
            [Color(hex: "78C8FF"), Color(hex: "4D77FF")],
            [Color(hex: "74D7B4"), Color(hex: "2CA57A")],
            [Color(hex: "FFB16C"), Color(hex: "FF6D8B")],
            [Color(hex: "FFD26E"), Color(hex: "A36EFF")],
            [Color(hex: "62D1D2"), Color(hex: "2E7FF3")],
            [Color(hex: "FF7A59"), Color(hex: "C94192")]
        ]
        let colors = palettes[index % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: String) {
        let cleanValue = hex.replacingOccurrences(of: "#", with: "")
        var intValue: UInt64 = 0
        Scanner(string: cleanValue).scanHexInt64(&intValue)

        let red = Double((intValue >> 16) & 0xFF) / 255
        let green = Double((intValue >> 8) & 0xFF) / 255
        let blue = Double(intValue & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}

extension Font {
    static func calm(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let isReviewVersion = UserDefaults.standard.bool(forKey: "glampro.review.font.mode")
        return .system(size: size, weight: weight, design: isReviewVersion ? .default : .rounded)
    }
}

enum EnglishTextFallback {
    static func resolve(_ text: String?, fallback: String) -> String {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return fallback
        }
        return containsNonEnglish(raw) ? fallback : raw
    }

    private static func containsNonEnglish(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value <= 0x007F { continue } // ASCII
            if scalar.properties.isEmoji || scalar.properties.isEmojiPresentation { continue }
            if CharacterSet.symbols.contains(scalar) { continue }
            return true
        }
        return false
    }
}
