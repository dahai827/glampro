import SwiftUI

struct ScreenContainer<Content: View>: View {
    let background: AnyView
    let showBrand: Bool
    let topSpacing: CGFloat
    let bottomSpacing: CGFloat
    private let content: Content

    init<Background: View>(showBrand: Bool = true, topSpacing: CGFloat? = nil, bottomSpacing: CGFloat = 98, @ViewBuilder background: () -> Background, @ViewBuilder content: () -> Content) {
        self.background = AnyView(background())
        self.showBrand = showBrand
        self.topSpacing = topSpacing ?? (showBrand ? 54 : 0)
        self.bottomSpacing = bottomSpacing
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            background
                .ignoresSafeArea()

            content
                .padding(.top, topSpacing)
                .padding(.bottom, bottomSpacing)

            if showBrand {
                BrandPill()
                    .padding(.top, 9)
            }
        }
    }
}

struct BrandPill: View {
    var body: some View {
        HStack(spacing: 7) {
            BrandOrb(size: 18)
            Text("Calm AI")
                .font(.calm(15, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "AF745D").opacity(0.82))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )
    }
}

struct BrandOrb: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(CalmTheme.brandGradient)
            Circle()
                .fill(Color.black.opacity(0.2))
                .frame(width: size * 0.64, height: size * 0.64)
            Circle()
                .fill(Color.black)
                .frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}

struct CircleIconButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    init(icon: String, size: CGFloat = 34, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CapsuleChip: View {
    let title: String
    var systemImage: String?
    var badgeText: String?
    var isSelected = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
            }

            Text(title)
                .font(.calm(16, weight: .bold))

            if let badgeText {
                Text(badgeText)
                    .font(.calm(13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .frame(height: 25)
                    .background(Capsule().fill(CalmTheme.pink))
            }
        }
        .foregroundColor(isSelected ? .black : .white.opacity(0.94))
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(
            Capsule()
                .fill(isSelected ? Color.white : Color.white.opacity(0.09))
        )
    }
}

struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.calm(21, weight: .heavy))
                .foregroundColor(.white)

            Spacer()

            if let actionTitle {
                Button(action: { action?() }) {
                    HStack(spacing: 5) {
                        Text(actionTitle)
                            .font(.calm(15, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 33)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PlaceholderArtwork: View {
    let paletteIndex: Int
    var cornerRadius: CGFloat = 20
    var symbol: String? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(CalmTheme.cardGradient(paletteIndex))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear, Color.black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 130, height: 130)
                .blur(radius: 22)
                .offset(x: -44, y: -32)

            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 180, height: 180)
                .blur(radius: 24)
                .offset(x: 64, y: 76)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}



struct ClippedArtworkContainer<Content: View>: View {
    let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .clipped()
    }
}

struct RemoteArtworkView: View {
    let url: URL?
    let paletteIndex: Int
    let cornerRadius: CGFloat
    var symbol: String? = nil
    var contentMode: ContentMode = .fill

    var body: some View {
        ZStack {
            PlaceholderArtwork(paletteIndex: paletteIndex, cornerRadius: cornerRadius, symbol: symbol)

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                            .transition(.opacity)
                    case .empty:
                        Color.clear
                    case .failure:
                        Color.clear
                    @unknown default:
                        Color.clear
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct GradientButton: View {
    let title: String
    let subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(.calm(17, weight: .bold))
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.calm(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.94))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(CalmTheme.accentGradient)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProgressRing: View {
    let progress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(CalmTheme.purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.calm(28, weight: .bold))
                    .foregroundColor(CalmTheme.purple)
                Text("RENDERING")
                    .font(.calm(10, weight: .bold))
                    .kerning(1)
                    .foregroundColor(.white.opacity(0.56))
            }
        }
    }
}
