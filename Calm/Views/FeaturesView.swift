import SwiftUI

struct FeaturesView: View {
    let onSelectFeature: (FeatureCardModel) -> Void
    let onClose: () -> Void

    @GestureState private var dragTranslation: CGFloat = 0

    private let columns = [
        GridItem(.flexible(), spacing: 18, alignment: .top),
        GridItem(.flexible(), spacing: 18, alignment: .top)
    ]

    private let dismissThreshold: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            // Keep only a small top reveal across devices so the sheet consistently covers home.
            let topReveal = max(proxy.safeAreaInsets.top - 30, 14)
            let sheetHeight = max(proxy.size.height - topReveal, 520)

            ZStack(alignment: .bottom) {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                sheetBody(height: sheetHeight)
                    .offset(y: max(dragTranslation, 0))
                    .gesture(sheetDragGesture)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func sheetBody(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            Text("Features")
                .font(.calm(20, weight: .heavy))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)
                .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                    ForEach(MockData.featureCards) { item in
                        featureCard(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(CalmTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: -4)
    }

    private func featureCard(_ item: FeatureCardModel) -> some View {
        Button(action: { onSelectFeature(item) }) {
            VStack(alignment: .leading, spacing: 10) {
                PlaceholderArtwork(paletteIndex: item.paletteIndex, cornerRadius: 14, symbol: item.symbol)
                    .frame(height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.calm(14, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.calm(12, weight: .medium))
                        .foregroundColor(CalmTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = max(value.translation.height, 0)
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > dismissThreshold || value.predictedEndTranslation.height > 180
                if shouldDismiss {
                    onClose()
                }
            }
    }
}

struct AIChatView: View {
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    let onClose: () -> Void

    private let pageHorizontalPadding: CGFloat = 15
    private let inputPanelHorizontalPadding: CGFloat = 10
    private let inputPanelBottomPadding: CGFloat = 10
    private let contentBottomInset: CGFloat = 164

    var body: some View {
        ZStack(alignment: .bottom) {
            CalmTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerRow
                    .padding(.top, 8)

                introMessage
                    .padding(.top, 12)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, pageHorizontalPadding)
            .padding(.bottom, contentBottomInset)

            inputPanel
                .padding(.horizontal, inputPanelHorizontalPadding)
                .padding(.bottom, inputPanelBottomPadding)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            CircleIconButton(icon: "xmark", size: 34, action: onClose)

            HStack(spacing: 8) {
                BrandOrb(size: 24)
                Text("Glam AI")
                    .font(.calm(42, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button(action: {}) {
                Text("Clear")
                    .font(.calm(17, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 15)
                    .frame(height: 33)
                    .background(
                        Capsule()
                        .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var introMessage: some View {
        Text("Hey! I’m Glam AI. Send me a photo and I’ll edit it however you want — change outfits, swap backgrounds, adjust details, or put people together in one scene. I can also create images from scratch and turn photos into videos. What should we make?")
            .font(.calm(15.5, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 84, height: 32)
                .overlay(
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("Tools")
                            .font(.calm(15, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.95))
                )

            HStack(spacing: 10) {
                TextField("Describe your idea or ask", text: $inputText)
                    .font(.calm(17, weight: .medium))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .focused($isInputFocused)

                Button(action: {}) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.42))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(minHeight: 138)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = true
        }
    }
}

struct CustomStylesView: View {
    let onClose: () -> Void

    private let pageHorizontalPadding: CGFloat = 15

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                CalmTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.top, 20)
                        .padding(.horizontal, pageHorizontalPadding)

                    imageCard
                        .padding(.top, 20)
                        .padding(.horizontal, pageHorizontalPadding)

                    promptCard
                        .padding(.top, 16)
                        .padding(.horizontal, pageHorizontalPadding)

                    generateSection
                        .padding(.top, 16)
                        .padding(.horizontal, pageHorizontalPadding)

                    Spacer(minLength: 4)

                    generationsPanel
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Create Style")
                .font(.calm(22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack {
                CircleIconButton(icon: "xmark", size: 34, action: onClose)
                Spacer()
            }
        }
    }

    private var imageCard: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.11))
            .overlay {
                Button(action: {}) {
                    Text("Change Image")
                        .font(.calm(18, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.92))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 30)
            }
            .frame(height: 208)
    }

    private var promptCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.88))

                Text("Select Generation Mode")
                    .font(.calm(16, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.clear)
                .overlay(alignment: .topLeading) {
                    Text("Describe how to modify\nyour Style")
                        .font(.calm(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.leading, 6)
                        .padding(.top, 10)
                }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(height: 218)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
    }

    private var generateSection: some View {
        VStack(spacing: 8) {
            Button(action: {}) {
                Text("Generate")
                    .font(.calm(18, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            Text("1 Coin")
                .font(.calm(13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var generationsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 50, height: 5)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)

            Text("My Generations")
                .font(.calm(18, weight: .bold))
                .foregroundColor(.white.opacity(0.58))
                .padding(.top, 14)
                .padding(.horizontal, 15)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 154)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

struct MotionSwapView: View {
    let onClose: () -> Void

    private let pageHorizontalPadding: CGFloat = 15

    var body: some View {
        ZStack {
            CalmTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 20)
                    .padding(.horizontal, pageHorizontalPadding)

                uploadCards
                    .padding(.top, 16)
                    .padding(.horizontal, pageHorizontalPadding)

                motionPromptCard
                    .padding(.top, 16)
                    .padding(.horizontal, pageHorizontalPadding)

                generateSection
                    .padding(.top, 16)
                    .padding(.horizontal, pageHorizontalPadding)

                Spacer(minLength: 4)

                generationsPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var header: some View {
        ZStack {
            Text("Create Style")
                .font(.calm(22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack {
                CircleIconButton(icon: "xmark", size: 34, action: onClose)
                Spacer()
            }
        }
    }

    private var uploadCards: some View {
        HStack(spacing: 8) {
            uploadCard(
                title: "Pick a photo for\nyour character",
                buttonTitle: "Add Image"
            )

            uploadCard(
                title: "The motion from\nthe video will be\napplied to your\nimage",
                buttonTitle: "Add Video"
            )
        }
        .frame(height: 198)
    }

    private func uploadCard(title: String, buttonTitle: String) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.11))
            .overlay {
                VStack(spacing: 18) {
                    Text(title)
                        .font(.calm(13, weight: .bold))
                        .foregroundColor(.white.opacity(0.52))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1.4)
                        .frame(height: 66, alignment: .top)

                    Button(action: {}) {
                        Text(buttonTitle)
                            .font(.calm(16, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 0)
                }
                .padding(.top, 18)
            }
    }

    private var motionPromptCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.88))

                Text("Motion Swap")
                    .font(.calm(16, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.clear)
                .overlay(alignment: .topLeading) {
                    Text("A character dances")
                        .font(.calm(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))
                        .padding(.leading, 6)
                        .padding(.top, 12)
                }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(height: 218)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
    }

    private var generateSection: some View {
        VStack(spacing: 8) {
            Button(action: {}) {
                Text("Generate")
                    .font(.calm(18, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            Text("1 Coin")
                .font(.calm(13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var generationsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 50, height: 5)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)

            Text("My Generations")
                .font(.calm(18, weight: .bold))
                .foregroundColor(.white.opacity(0.58))
                .padding(.top, 14)
                .padding(.horizontal, 15)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 154)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}
