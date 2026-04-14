import SwiftUI
import StoreKit

struct SubscriptionOfferOneView: View {
    @EnvironmentObject private var appBootstrap: AppBootstrapStore
    @EnvironmentObject private var previewGenerationStore: PreviewGenerationStore

    let onClose: () -> Void
    let onContinue: () -> Void

    @State private var phase: SubscriptionGuidePhase = .generating
    @State private var progress: Double = 0
    @State private var remainingSeconds = 180
    @State private var showPaywall = false
    @State private var progressTask: Task<Void, Never>?
    @State private var countdownTask: Task<Void, Never>?
    @State private var guideStartedAt = Date()

    private var selectedItem: RemoteFeatureItem? {
        previewGenerationStore.activeItem ?? appBootstrap.selectedPreviewItem
    }

    private var createdTimeText: String {
        let elapsed = max(Int(Date().timeIntervalSince(guideStartedAt)), 0)
        if elapsed < 60 {
            return "Just now"
        }
        if elapsed < 3600 {
            return "\(elapsed / 60)m ago"
        }
        return "\(elapsed / 3600)h ago"
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                switch phase {
                case .generating:
                    SubscriptionGuideGeneratingView(progress: progress)
                case .unlockPrompt:
                    guidePromptView(
                        title: "Your preview is almost ready",
                        subtitle: "Unlock full results, unlimited styles, and priority generation with Glam Pro.",
                        buttonTitle: "Unlock Result",
                        caption: "Tap anywhere to continue"
                    ) {
                        openPaywall()
                    }
                case .countdown:
                    guidePromptView(
                        title: "Special offer ending in \(formatCountdown(remainingSeconds))",
                        subtitle: "Keep your creation, unlock HD exports, and remove all limits before the timer ends.",
                        buttonTitle: "Unlock Now",
                        caption: "Offer reserved for this task"
                    ) {
                        openPaywall()
                    }
                case .exitConfirm:
                    exitConfirmView
                case .activeTasks:
                    activeTasksView
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background {
                SubscriptionBackdropView(item: selectedItem, blurRadius: phase == .generating ? 0 : 28, darkness: 0.56)
                    .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                if phase != .generating && phase != .exitConfirm {
                    guideTopBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .zIndex(2)
                }
            }
        }
        .onAppear {
            guideStartedAt = Date()
            startGuideAnimationIfNeeded()
        }
        .onDisappear(perform: stopGuideTasks)
        .fullScreenCover(isPresented: $showPaywall) {
            SubscriptionOfferTwoView(
                onClose: { showPaywall = false },
                onSubscribed: {
                    showPaywall = false
                    onClose()
                }
            )
        }
    }

    private func guidePromptView(
        title: String,
        subtitle: String,
        buttonTitle: String,
        caption: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 48)

            SubscriptionGuidePreviewCard(item: selectedItem)
                .padding(.horizontal, 24)

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                Text(title)
                    .font(.calm(30, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text(buttonTitle)
                            .font(.calm(18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 29, style: .continuous)
                            .fill(GlamProTheme.accentGradient)
                    )
                }
                .buttonStyle(.plain)

                Text(caption)
                    .font(.calm(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.64))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 22)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.36))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    private var exitConfirmView: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Leave the unlock flow?")
                    .font(.calm(26, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Your task is still saved. View active tasks or claim the unlock offer now.")
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .activeTasks
                        }
                    } label: {
                        Text("View Active Tasks")
                            .font(.calm(18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(GlamProTheme.accentGradient)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        openPaywall()
                    } label: {
                        Text("Unlock Instead")
                            .font(.calm(17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(Color.white.opacity(0.09))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(hex: "17171A"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private var activeTasksView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 88)

            VStack(alignment: .leading, spacing: 16) {
                Text("Active Tasks")
                    .font(.calm(30, weight: .heavy))
                    .foregroundColor(.white)

                Button(action: openPaywall) {
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Special Offer")
                                .font(.calm(16, weight: .heavy))
                                .foregroundColor(.white)
                            Text("Unlock Pro for unlimited generations and faster results.")
                                .font(.calm(13, weight: .medium))
                                .foregroundColor(.white.opacity(0.78))
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("50% OFF")
                                .font(.calm(20, weight: .heavy))
                                .foregroundColor(.white)
                            Text("Unlock")
                                .font(.calm(13, weight: .bold))
                                .foregroundColor(.white.opacity(0.88))
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(GlamProTheme.accentGradient)
                    )
                }
                .buttonStyle(.plain)

                Button(action: openPaywall) {
                    HStack(spacing: 14) {
                        SubscriptionGuidePreviewCard(item: selectedItem, compact: true)
                            .frame(width: 92, height: 120)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                SubscriptionPill(title: remainingSeconds > 0 ? "Running" : "Ready", tint: remainingSeconds > 0 ? GlamProTheme.orange : GlamProTheme.purple)
                                SubscriptionPill(title: createdTimeText, tint: GlamProTheme.sky)
                            }

                            Text(selectedItem?.title ?? "AI Creation")
                                .font(.calm(18, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)

                            Text(remainingSeconds > 0 ? "Unlock to view the HD result before the countdown ends." : "Your result is ready to unlock right now.")
                                .font(.calm(13, weight: .medium))
                                .foregroundColor(.white.opacity(0.76))
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.black.opacity(0.34))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 20)
        }
    }

    private var guideTopBar: some View {
        HStack {
            CircleIconButton(icon: "xmark", size: 40) {
                handleGuideCloseTapped()
            }
            .contentShape(Rectangle())

            Spacer(minLength: 0)

            SubscriptionPill(title: phase == .countdown ? formatCountdown(remainingSeconds) : "Glam Pro", tint: phase == .countdown ? GlamProTheme.orange : GlamProTheme.purple)
        }
        .frame(maxWidth: .infinity)
    }

    private func startGuideAnimationIfNeeded() {
        guard progressTask == nil else { return }
        phase = .generating
        progress = 0
        remainingSeconds = 180

        progressTask = Task {
            for step in 0...100 {
                if Task.isCancelled { return }
                await MainActor.run {
                    progress = Double(step) / 100
                }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .unlockPrompt
                }
                startCountdownIfNeeded()
            }
        }
    }

    private func startCountdownIfNeeded() {
        guard countdownTask == nil else { return }
        countdownTask = Task {
            while !Task.isCancelled && remainingSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    remainingSeconds = max(remainingSeconds - 1, 0)
                }
            }
        }
    }

    private func stopGuideTasks() {
        progressTask?.cancel()
        countdownTask?.cancel()
        progressTask = nil
        countdownTask = nil
    }

    private func handleGuideCloseTapped() {
        switch phase {
        case .unlockPrompt:
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = .countdown
            }
        case .countdown:
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = .exitConfirm
            }
        case .activeTasks:
            onClose()
        case .generating, .exitConfirm:
            break
        }
    }

    private func openPaywall() {
        showPaywall = true
    }
}

struct SubscriptionOfferTwoView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appBootstrap: AppBootstrapStore
    @EnvironmentObject private var previewGenerationStore: PreviewGenerationStore

    @StateObject private var subscriptionStore = SubscriptionStore.shared
    @State private var selectedPlanID: String?
    @State private var actionState: SubscriptionPurchaseActionState = .idle
    @State private var errorMessage: String?
    @State private var showCloseButton = false
    @State private var closeRevealTask: Task<Void, Never>?

    let onClose: () -> Void
    var onSubscribed: (() -> Void)? = nil
    var showsCloseWithDelay = true

    private let featureBullets = [
        "Unlimited AI creations",
        "HD exports with no watermark",
        "Priority generation speed",
        "Exclusive premium styles",
        "Bonus credits every cycle",
        "Cancel anytime"
    ]

    private var selectedItem: RemoteFeatureItem? {
        previewGenerationStore.activeItem ?? appBootstrap.selectedPreviewItem
    }

    private var yearlyPlan: SubscriptionPlan? {
        subscriptionStore.plans.first(where: \.isYearly)
    }

    private var weeklyPlan: SubscriptionPlan? {
        subscriptionStore.plans.first(where: \.isWeekly)
    }

    private var effectiveSelectedPlan: SubscriptionPlan? {
        if let selectedPlanID,
           let selected = subscriptionStore.plans.first(where: { $0.id == selectedPlanID }) {
            return selected
        }
        return yearlyPlan ?? weeklyPlan ?? subscriptionStore.plans.first
    }

    private var canInteract: Bool {
        actionState == .idle
    }

    private var continueButtonTitle: String {
        switch actionState {
        case .idle:
            return "Continue"
        case .processing:
            return "Processing"
        case .verifying:
            return "Verifying"
        case .restoring:
            return "Restoring"
        }
    }

    private var continueButtonSubtitle: String? {
        guard actionState == .idle else { return nil }
        return effectiveSelectedPlan?.buttonSubtitle
    }

    private var closeButtonVisible: Bool {
        sessionManager.isPro || !showsCloseWithDelay || showCloseButton
    }

    var body: some View {
        GeometryReader { geometry in
            let safeBottom = geometry.safeAreaInsets.bottom

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: max(geometry.size.height * 0.27, 210))

                    paywallPanel(bottomInset: safeBottom)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height, alignment: .bottom)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background {
                SubscriptionBackdropView(item: selectedItem, blurRadius: 22, darkness: 0.42)
                    .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .zIndex(2)
            }
        }
        .task {
            await subscriptionStore.preloadProducts()
            syncSelectedPlanIfNeeded()
        }
        .onAppear {
            syncSelectedPlanIfNeeded()
            revealCloseButtonIfNeeded()
        }
        .onDisappear {
            closeRevealTask?.cancel()
            closeRevealTask = nil
        }
        .onChange(of: subscriptionStore.plans.map(\.id)) { _ in
            syncSelectedPlanIfNeeded()
        }
        .onChange(of: sessionManager.isPro) { isPro in
            guard isPro else { return }
            onSubscribed?()
        }
        .alert(
            "Subscription",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.24)))
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(closeButtonVisible ? 1 : 0)
            .allowsHitTesting(closeButtonVisible)

            Spacer(minLength: 0)

            Button {
                restorePurchase()
            } label: {
                Text(actionState == .restoring ? "Restoring..." : "Restore")
                    .font(.calm(14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.black.opacity(0.24)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(actionState != .idle)
        }
        .frame(maxWidth: .infinity)
    }

    private func paywallPanel(bottomInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Unlock Glam Pro")
                    .font(.calm(32, weight: .heavy))
                    .foregroundColor(.white)

                Text("Subscribe for unlimited creation, faster generation, and premium templates.")
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(featureBullets, id: \.self) { bullet in
                    SubscriptionFeatureRow(title: bullet)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                if let yearlyPlan {
                    yearlyCard(yearlyPlan)
                }

                if let weeklyPlan {
                    weeklyCard(weeklyPlan)
                }
            }

            Button {
                purchaseSelectedPlan()
            } label: {
                VStack(spacing: continueButtonSubtitle == nil ? 0 : 2) {
                    Text(continueButtonTitle)
                        .font(.calm(18, weight: .bold))
                        .foregroundColor(.white)
                    if let continueButtonSubtitle {
                        Text(continueButtonSubtitle)
                            .font(.calm(13, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(canInteract ? LinearGradient(colors: [GlamProTheme.purple, Color(hex: "8D54FF")], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canInteract || effectiveSelectedPlan == nil)

            VStack(spacing: 8) {
                Text("Auto-renewable subscription. Cancel anytime in App Store settings.")
                    .font(.calm(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Text("Terms")
                    Text("·")
                    Text("Privacy")
                    Text("·")
                    Text("Restore Purchase")
                }
                .font(.calm(12, weight: .medium))
                .foregroundColor(.white.opacity(0.54))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, max(bottomInset, 10) + 18)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black.opacity(0.38))
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func yearlyCard(_ plan: SubscriptionPlan) -> some View {
        let isSelected = effectiveSelectedPlan?.id == plan.id
        let leftText = appBootstrap.isReviewVersion ? plan.weeklyEquivalentText : plan.annualDisplayText
        let rightText = appBootstrap.isReviewVersion ? plan.annualDisplayText : plan.weeklyEquivalentText

        return Button {
            selectPlan(plan)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.shortTitle)
                        .font(.calm(18, weight: .heavy))
                        .foregroundColor(.white)

                    Text(leftText)
                        .font(.calm(14, weight: .bold))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(plan.detailText)
                        .font(.calm(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(rightText)
                    .font(.calm(28, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color(hex: "8E33EA").opacity(0.9) : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.18), lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Text(yearlyBadgeText)
                        .font(.calm(12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Capsule().fill(Color(hex: "6B1DD8").opacity(0.96)))
                        .offset(x: -10, y: -12)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canInteract)
    }

    private func weeklyCard(_ plan: SubscriptionPlan) -> some View {
        let isSelected = effectiveSelectedPlan?.id == plan.id

        return Button {
            selectPlan(plan)
            purchaseSelectedPlan(triggeredByWeeklyTap: true)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.shortTitle)
                        .font(.calm(18, weight: .heavy))
                        .foregroundColor(.white)
                    Text(plan.detailText)
                        .font(.calm(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer(minLength: 8)

                Text(plan.weeklyDisplayText)
                    .font(.calm(24, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color(hex: "8E33EA").opacity(0.9) : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.18), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canInteract)
    }

    private var yearlyBadgeText: String {
        if let yearlyAmount = yearlyPlan?.rawAmount,
           let weeklyAmount = weeklyPlan?.rawAmount,
           yearlyAmount > 0,
           weeklyAmount > 0 {
            let annualFromWeekly = weeklyAmount * 52
            let savings = Int((((annualFromWeekly - yearlyAmount) / annualFromWeekly) * 100).rounded())
            if savings > 0 {
                return "Save \(savings)%"
            }
        }
        return yearlyPlan?.badgeText ?? "Best"
    }

    private func revealCloseButtonIfNeeded() {
        closeRevealTask?.cancel()
        closeRevealTask = nil

        if closeButtonVisible {
            showCloseButton = true
            return
        }

        showCloseButton = false
        closeRevealTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showCloseButton = true
            }
        }
    }

    private func syncSelectedPlanIfNeeded() {
        if let selectedPlanID,
           subscriptionStore.plans.contains(where: { $0.id == selectedPlanID }) {
            return
        }
        selectedPlanID = yearlyPlan?.id ?? weeklyPlan?.id ?? subscriptionStore.plans.first?.id
    }

    private func selectPlan(_ plan: SubscriptionPlan) {
        guard canInteract else { return }
        selectedPlanID = plan.id
    }

    private func purchaseSelectedPlan(triggeredByWeeklyTap: Bool = false) {
        guard canInteract else { return }
        guard let plan = effectiveSelectedPlan else {
            errorMessage = SubscriptionStoreError.missingProductInfo.errorDescription
            return
        }

        if triggeredByWeeklyTap && !plan.isWeekly {
            return
        }

        Task {
            actionState = .processing
            do {
                try await subscriptionStore.purchase(plan: plan, sessionManager: sessionManager) {
                    actionState = .verifying
                }
            } catch let error as SubscriptionStoreError {
                if case .userCancelled = error {
                    actionState = .idle
                    return
                }
                actionState = .idle
                errorMessage = error.errorDescription
            } catch {
                actionState = .idle
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restorePurchase() {
        guard canInteract else { return }

        Task {
            actionState = .restoring
            do {
                try await subscriptionStore.restorePurchases(sessionManager: sessionManager) {
                    actionState = .verifying
                }
            } catch let error as SubscriptionStoreError {
                actionState = .idle
                if case .userCancelled = error {
                    return
                }
                errorMessage = error.errorDescription
            } catch {
                actionState = .idle
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum SubscriptionGuidePhase {
    case generating
    case unlockPrompt
    case countdown
    case exitConfirm
    case activeTasks
}

private enum SubscriptionPurchaseActionState: Equatable {
    case idle
    case processing
    case verifying
    case restoring
}

struct SubscriptionPlan: Identifiable, Equatable {
    let id: String
    let storeKitProductID: String
    let title: String
    let planType: String
    let detailText: String
    let displayPrice: String
    let annualPriceText: String?
    let weeklyEquivalentText: String
    let badgeText: String?
    let rawAmount: Double?
    let product: Product?

    var isYearly: Bool {
        planType == "yearly"
    }

    var isWeekly: Bool {
        planType == "weekly"
    }

    var shortTitle: String {
        if isYearly { return "Yearly" }
        if isWeekly { return "Weekly" }
        return title
    }

    var annualDisplayText: String {
        annualPriceText ?? displayPrice
    }

    var weeklyDisplayText: String {
        if weeklyEquivalentText.contains("/week") {
            return weeklyEquivalentText
        }
        return "\(weeklyEquivalentText)/week"
    }

    var buttonSubtitle: String? {
        if isYearly {
            return "\(annualDisplayText) / year"
        }
        return weeklyDisplayText
    }
}

private struct SubscriptionProductsResponse: Decodable {
    let data: [SubscriptionProductConfiguration]?
    let error: String?
    let status: Int?
}

private struct SubscriptionProductConfiguration: Decodable {
    let productID: String
    let productName: String?
    let description: String?
    let planType: String?
    let billingInterval: String?
    let amount: Double?
    let currency: String?
    let creditsPerCycle: Int?
    let initialCredits: Int?
    let tags: [String]?
    let features: [String]?

    enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case productName = "product_name"
        case description
        case planType = "plan_type"
        case billingInterval = "billing_interval"
        case amount
        case currency
        case creditsPerCycle = "credits_per_cycle"
        case initialCredits = "initial_credits"
        case tags
        case features
    }
}

private struct SubscriptionVerifyRequest: Encodable {
    let transactionId: String
    let signedTransactionInfo: String
    let signedRenewalInfo: String?
}

private struct SubscriptionVerifyResponse: Decodable {
    let success: Bool?
    let subscriptionStatus: String?
    let subscriptionExpireAt: String?
    let planType: String?
    let creditsBalance: Int?
    let creditsGranted: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case subscriptionStatus = "subscription_status"
        case subscriptionExpireAt = "subscription_expire_at"
        case planType = "plan_type"
        case creditsBalance = "credits_balance"
        case creditsGranted = "credits_granted"
        case message
    }
}

private enum SubscriptionStoreError: LocalizedError {
    case userCancelled
    case purchasePending
    case missingProductInfo
    case noSubscriptionFound
    case verificationFailed(String)
    case restoreFailed(String)
    case purchaseNotAllowed

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase cancelled"
        case .purchasePending:
            return "Your purchase is pending approval. Please try again in a moment."
        case .missingProductInfo:
            return "Subscription products are not available right now. Please try again later."
        case .noSubscriptionFound:
            return "No active subscription was found to restore."
        case let .verificationFailed(message):
            return message.isEmpty ? "Subscription verification failed. Please try again." : message
        case let .restoreFailed(message):
            return message.isEmpty ? "Restore failed. Please try again." : message
        case .purchaseNotAllowed:
            return "Please sign in to your Apple ID in the App Store and try again."
        }
    }
}

@MainActor
final class SubscriptionStore: ObservableObject {
    static let shared = SubscriptionStore()

    @Published private(set) var plans: [SubscriptionPlan] = SubscriptionStore.fallbackPlans
    @Published private(set) var isLoadingProducts = false

    private let apiClient: APIClient
    private var didLoadProducts = false

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func preloadProducts(force: Bool = false) async {
        guard force || !didLoadProducts || plans.isEmpty else { return }
        guard !isLoadingProducts else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        let configs = (try? await fetchConfigurations()) ?? Self.fallbackConfigurations
        let normalizedConfigs = normalizeConfigurations(configs)
        let ids = normalizedConfigs.map(\.productID)

        var productsByID: [String: Product] = [:]
        if !ids.isEmpty, let loadedProducts = try? await Product.products(for: ids) {
            productsByID = Dictionary(uniqueKeysWithValues: loadedProducts.map { ($0.id, $0) })
        }

        let resolvedPlans = normalizedConfigs.map { config in
            makePlan(from: config, product: productsByID[config.productID])
        }

        plans = resolvedPlans.isEmpty ? Self.fallbackPlans : resolvedPlans
        didLoadProducts = true
    }

    func purchase(
        plan: SubscriptionPlan,
        sessionManager: SessionManager,
        onVerificationStarted: @escaping @MainActor () -> Void
    ) async throws {
        if product(for: plan) == nil {
            await preloadProducts(force: true)
        }

        guard let product = product(for: plan) else {
            throw SubscriptionStoreError.missingProductInfo
        }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                onVerificationStarted()
                try await verifySubscription(verification: verification, sessionManager: sessionManager)
            case .userCancelled:
                throw SubscriptionStoreError.userCancelled
            case .pending:
                throw SubscriptionStoreError.purchasePending
            @unknown default:
                throw SubscriptionStoreError.verificationFailed("Purchase result is not supported on this iOS version.")
            }
        } catch let error as SubscriptionStoreError {
            throw error
        } catch let error as Product.PurchaseError {
            switch error {
            case .purchaseNotAllowed:
                throw SubscriptionStoreError.purchaseNotAllowed
            default:
                throw SubscriptionStoreError.verificationFailed(error.localizedDescription)
            }
        } catch {
            throw SubscriptionStoreError.verificationFailed(error.localizedDescription)
        }
    }

    func restorePurchases(
        sessionManager: SessionManager,
        onVerificationStarted: @escaping @MainActor () -> Void
    ) async throws {
        do {
            try await AppStore.sync()

            let knownIDs = Set(plans.map(\.storeKitProductID))
            var matchedVerification: VerificationResult<StoreKit.Transaction>?

            for await entitlement in Transaction.currentEntitlements {
                guard case .verified(let transaction) = entitlement else { continue }
                guard transaction.productType == .autoRenewable else { continue }
                if knownIDs.isEmpty || knownIDs.contains(transaction.productID) {
                    matchedVerification = entitlement
                    break
                }
            }

            guard let matchedVerification else {
                throw SubscriptionStoreError.noSubscriptionFound
            }

            onVerificationStarted()
            try await verifySubscription(verification: matchedVerification, sessionManager: sessionManager)
        } catch let error as SubscriptionStoreError {
            throw error
        } catch {
            throw SubscriptionStoreError.restoreFailed(error.localizedDescription)
        }
    }

    private func product(for plan: SubscriptionPlan) -> Product? {
        plans.first(where: { $0.id == plan.id })?.product
    }

    private func verifySubscription(
        verification: VerificationResult<StoreKit.Transaction>,
        sessionManager: SessionManager
    ) async throws {
        let transaction: StoreKit.Transaction
        do {
            transaction = try verification.payloadValue
        } catch {
            throw SubscriptionStoreError.verificationFailed("StoreKit could not verify this transaction.")
        }

        let status = await transaction.subscriptionStatus
        let requestBody = SubscriptionVerifyRequest(
            transactionId: String(transaction.id),
            signedTransactionInfo: verification.jwsRepresentation,
            signedRenewalInfo: status?.renewalInfo.jwsRepresentation
        )

        let response: SubscriptionVerifyResponse = try await sessionManager.performAuthenticatedRequest { token in
            try await self.apiClient.post(
                path: "subscription-verify",
                body: requestBody,
                bearerToken: token
            )
        }

        if response.success == false {
            throw SubscriptionStoreError.verificationFailed(response.message ?? "Subscription verification failed.")
        }

        if let status = response.subscriptionStatus,
           let creditsBalance = response.creditsBalance {
            let updatedStatus = UserStatus(
                subscriptionStatus: status,
                subscriptionExpireAt: response.subscriptionExpireAt,
                planType: response.planType,
                creditsBalance: creditsBalance,
                isAnonymous: sessionManager.userStatus?.isAnonymous ?? true
            )
            sessionManager.applyUserStatus(updatedStatus)
        } else {
            await sessionManager.refreshUserStatus()
        }

        await transaction.finish()
    }

    private func fetchConfigurations() async throws -> [SubscriptionProductConfiguration] {
        let response: SubscriptionProductsResponse = try await apiClient.get(
            path: "subscription-products",
            queryItems: [
                URLQueryItem(name: "app_id", value: APIConfig.appID),
                URLQueryItem(name: "platform", value: "apple")
            ]
        )

        let configs = response.data ?? []
        return configs.isEmpty ? Self.fallbackConfigurations : configs
    }

    private func normalizeConfigurations(_ configs: [SubscriptionProductConfiguration]) -> [SubscriptionProductConfiguration] {
        let preferred = configs.filter {
            let planType = normalizePlanType($0.planType, billingInterval: $0.billingInterval)
            return planType == "yearly" || planType == "weekly"
        }

        let source = preferred.isEmpty ? Self.fallbackConfigurations : preferred
        return source.sorted { lhs, rhs in
            let leftRank = sortRank(for: lhs)
            let rightRank = sortRank(for: rhs)
            return leftRank == rightRank ? lhs.productID < rhs.productID : leftRank < rightRank
        }
    }

    private func sortRank(for config: SubscriptionProductConfiguration) -> Int {
        switch normalizePlanType(config.planType, billingInterval: config.billingInterval) {
        case "yearly": return 0
        case "weekly": return 1
        default: return 2
        }
    }

    private func makePlan(from config: SubscriptionProductConfiguration, product: Product?) -> SubscriptionPlan {
        let normalizedPlanType = normalizePlanType(config.planType, billingInterval: config.billingInterval)
        let rawAmount = product.map { NSDecimalNumber(decimal: $0.price).doubleValue } ?? config.amount
        let baseDisplayPrice = product?.displayPrice ?? formatCurrency(config.amount, currencyCode: config.currency) ?? (normalizedPlanType == "weekly" ? "$6.99" : "$39.99")

        let weeklyEquivalent: String
        if normalizedPlanType == "yearly" {
            if let product {
                let perWeek = NSDecimalNumber(decimal: product.price).dividing(by: NSDecimalNumber(value: 52)).decimalValue
                weeklyEquivalent = "\(perWeek.formatted(product.priceFormatStyle))/week"
            } else if let amount = config.amount {
                weeklyEquivalent = "\(formatCurrency(amount / 52, currencyCode: config.currency) ?? "$0.77")/week"
            } else {
                weeklyEquivalent = "$0.77/week"
            }
        } else {
            if baseDisplayPrice.contains("/week") {
                weeklyEquivalent = baseDisplayPrice
            } else {
                weeklyEquivalent = "\(baseDisplayPrice)/week"
            }
        }

        let detailText: String
        if let description = config.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            detailText = description
        } else if let credits = config.creditsPerCycle, credits > 0 {
            detailText = normalizedPlanType == "weekly" ? "\(credits) bonus credits every week" : "\(credits) bonus credits every cycle"
        } else if let initialCredits = config.initialCredits, initialCredits > 0 {
            detailText = "Includes \(initialCredits) bonus credits"
        } else {
            detailText = normalizedPlanType == "weekly" ? "Full access, billed weekly" : "Best value for unlimited access"
        }

        let annualPriceText = normalizedPlanType == "yearly" ? baseDisplayPrice : nil
        let badgeText = config.tags?.first?.trimmingCharacters(in: .whitespacesAndNewlines)

        return SubscriptionPlan(
            id: config.productID,
            storeKitProductID: config.productID,
            title: config.productName ?? (normalizedPlanType == "weekly" ? "Weekly" : "Yearly"),
            planType: normalizedPlanType,
            detailText: detailText,
            displayPrice: baseDisplayPrice,
            annualPriceText: annualPriceText,
            weeklyEquivalentText: weeklyEquivalent,
            badgeText: badgeText?.isEmpty == false ? badgeText : nil,
            rawAmount: rawAmount,
            product: product
        )
    }

    private func normalizePlanType(_ planType: String?, billingInterval: String?) -> String {
        let plan = planType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if plan == "yearly" || plan == "year" || plan == "annual" {
            return "yearly"
        }
        if plan == "weekly" || plan == "week" {
            return "weekly"
        }

        let interval = billingInterval?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if interval == "year" || interval == "annual" {
            return "yearly"
        }
        if interval == "week" {
            return "weekly"
        }
        return plan
    }

    private func formatCurrency(_ amount: Double?, currencyCode: String?) -> String? {
        guard let amount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = (currencyCode ?? "USD").uppercased()
        formatter.maximumFractionDigits = amount.rounded() == amount ? 0 : 2
        formatter.minimumFractionDigits = amount.rounded() == amount ? 0 : 2
        return formatter.string(from: NSNumber(value: amount))
    }

    private static let fallbackConfigurations: [SubscriptionProductConfiguration] = [
        SubscriptionProductConfiguration(
            productID: "yearly_pro",
            productName: "Yearly",
            description: "Best value for unlimited access and HD exports",
            planType: "yearly",
            billingInterval: "year",
            amount: 39.99,
            currency: "USD",
            creditsPerCycle: 2000,
            initialCredits: 0,
            tags: ["Best"],
            features: nil
        ),
        SubscriptionProductConfiguration(
            productID: "weekly_pro",
            productName: "Weekly",
            description: "Full premium access with flexible weekly billing",
            planType: "weekly",
            billingInterval: "week",
            amount: 6.99,
            currency: "USD",
            creditsPerCycle: 500,
            initialCredits: 0,
            tags: nil,
            features: nil
        )
    ]

    private static let fallbackPlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "yearly_pro",
            storeKitProductID: "yearly_pro",
            title: "Yearly",
            planType: "yearly",
            detailText: "Best value for unlimited access and HD exports",
            displayPrice: "$39.99",
            annualPriceText: "$39.99",
            weeklyEquivalentText: "$0.77/week",
            badgeText: "Best",
            rawAmount: 39.99,
            product: nil
        ),
        SubscriptionPlan(
            id: "weekly_pro",
            storeKitProductID: "weekly_pro",
            title: "Weekly",
            planType: "weekly",
            detailText: "Full premium access with flexible weekly billing",
            displayPrice: "$6.99",
            annualPriceText: nil,
            weeklyEquivalentText: "$6.99/week",
            badgeText: nil,
            rawAmount: 6.99,
            product: nil
        )
    ]
}

private struct SubscriptionBackdropView: View {
    let item: RemoteFeatureItem?
    let blurRadius: CGFloat
    let darkness: CGFloat

    private var paletteIndex: Int {
        abs((item?.id ?? "subscription-backdrop").hashValue) % 8
    }

    var body: some View {
        ZStack {
            RemoteArtworkView(
                url: item?.effectiveCoverURL,
                paletteIndex: paletteIndex,
                cornerRadius: 0,
                contentMode: .fill
            )
            .scaleEffect(1.08)
            .blur(radius: blurRadius)

            LinearGradient(
                colors: [Color.black.opacity(0.2), Color.black.opacity(darkness)],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.clear, Color.black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct SubscriptionGuideGeneratingView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 170, height: 170)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(GlamProTheme.accentGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(Int(progress * 100))%")
                        .font(.calm(30, weight: .heavy))
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 8) {
                Text("Preparing your unlock flow")
                    .font(.calm(28, weight: .heavy))
                    .foregroundColor(.white)

                Text("We are packaging your preview and loading the best Pro offer.")
                    .font(.calm(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

private struct SubscriptionGuidePreviewCard: View {
    let item: RemoteFeatureItem?
    var compact = false

    private var paletteIndex: Int {
        abs((item?.id ?? "subscription-preview-card").hashValue) % 8
    }

    var body: some View {
        ZStack(alignment: .center) {
            RemoteArtworkView(
                url: item?.effectiveCoverURL,
                paletteIndex: paletteIndex,
                cornerRadius: compact ? 22 : 30,
                contentMode: .fill
            )
            .blur(radius: compact ? 10 : 16)
            .overlay(Color.black.opacity(0.18))

            VStack(spacing: compact ? 8 : 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: compact ? 22 : 30, weight: .bold))
                    .foregroundColor(.white)

                if !compact {
                    Text("Premium Result")
                        .font(.calm(22, weight: .heavy))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(height: compact ? 120 : 320)
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 22 : 30, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct SubscriptionFeatureRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(GlamProTheme.purple)
                .frame(width: 22)

            Text(title)
                .font(.calm(16, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

private struct SubscriptionPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.calm(12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(tint.opacity(0.86)))
    }
}

private func formatCountdown(_ totalSeconds: Int) -> String {
    let clamped = max(totalSeconds, 0)
    let minutes = clamped / 60
    let seconds = clamped % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
