import SwiftUI
import SwiftData

@main
struct FlirtyApp: App {
    @State private var aiService = AIService()

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    init() {
        // SwiftData is in-memory under --ui-testing, but UserDefaults is not: a consent
        // left behind by one UI test run would skip the consent screen in the next.
        if isUITesting {
            UserDefaults.standard.removeObject(forKey: AIService.cloudConsentKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(aiService: aiService)
                .preferredColorScheme(.dark)
        }
        .modelContainer(
            for: [WomanProfile.self, Conversation.self],
            inMemory: isUITesting
        )
    }
}

struct RootView: View {
    let aiService: AIService
    @Environment(\.scenePhase) private var scenePhase
    @State private var availability: AIAvailability?
    @State private var diagnostic: String?
    @AppStorage(AIService.cloudConsentKey) private var cloudConsent = false

    var body: some View {
        Group {
            if let availability {
                switch availability {
                case .available:
                    WomenListView()
                case .cloudConsentRequired:
                    CloudConsentView { cloudConsent = true }
                case .notEnabled:
                    UnavailableView(
                        icon: "brain",
                        title: "Apple Intelligence Required",
                        message: "Flirty needs Apple Intelligence. Tap below, then go back to Settings › Apple Intelligence & Siri to turn it on.",
                        showSettings: true,
                        showRetry: true,
                        onRetry: checkAvailability,
                        diagnostic: diagnostic
                    )
                case .notEligible:
                    UnavailableView(
                        icon: "iphone.slash",
                        title: "Device Not Supported",
                        message: "Flirty requires an iPhone that supports Apple Intelligence.",
                        diagnostic: diagnostic
                    )
                case .notReady:
                    // iOS reports this reason both while the model downloads *and* while
                    // Apple Intelligence is simply switched off, so the copy has to cover
                    // both — claiming "downloading" alone leaves the user with nothing to do.
                    UnavailableView(
                        icon: "arrow.down.circle",
                        title: "AI Model Not Ready",
                        message: "Turn on Apple Intelligence to use Flirty. Tap below, then go back to Settings › Apple Intelligence & Siri. If it's already on, the model is still downloading.",
                        showSettings: true,
                        showRetry: true,
                        onRetry: checkAvailability,
                        diagnostic: diagnostic
                    )
                }
            } else {
                ZStack {
                    AppTheme.background.ignoresSafeArea()
                    ProgressView()
                        .tint(AppTheme.violet)
                }
            }
        }
        .onAppear { checkAvailability() }
        .onChange(of: scenePhase) { _, phase in
            // Availability is not fixed for the life of the process: the user may have
            // just switched Apple Intelligence on in Settings, or the model download may
            // have finished, while we were backgrounded. Without this the "enable it in
            // Settings" screen is a dead end that outlives the condition it describes.
            if phase == .active { checkAvailability() }
        }
        // Consent is granted on the consent screen and revoked from the list toolbar;
        // both must move the gate without a scene change.
        .onChange(of: cloudConsent) { checkAvailability() }
        .task(id: availability) {
            // A finishing download is the one transition that happens with no user action
            // and no scene change, so it is the only one the observers above cannot catch —
            // poll for it. The other states need a trip to Settings, which always comes
            // back through `scenePhase`. `.notEligible` is permanent; never poll it.
            guard availability == .notReady else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                checkAvailability()
            }
        }
    }

    private func checkAvailability() {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            // Simulator has no Apple Intelligence, so force the on-device answer; the
            // cloud-tier rows are still driven by the real resolver.
            let simulated = AIService.simulatesIneligibleDevice
            availability = AIService.resolve(
                onDevice: simulated ? .notEligible : .available,
                hasGateway: simulated,
                consentGiven: cloudConsent
            )
        } else {
            availability = aiService.checkAvailability()
            diagnostic = aiService.availabilityDiagnostic
        }
    }
}

/// Shown on iPhones without Apple Intelligence before any text leaves the device.
/// App Store guideline 5.1.2(i) requires explicit permission before sending personal
/// data to a third-party AI service.
struct CloudConsentView: View {
    let onAllow: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "icloud")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.primaryGradient)

                Text("Use cloud mode?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(
                    "This iPhone doesn't support Apple Intelligence, so Flirty can write replies in the cloud instead. Her messages, your notes about her, and your context are sent over HTTPS to the Flirty gateway, which uses Anthropic's Claude model. Nothing else is sent, and there is no account. You can turn this off any time from the cloud icon on the main screen."
                )
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

                Button("Allow", action: onAllow)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.primaryGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("cloudConsentAllow")
            }
        }
    }
}

struct UnavailableView: View {
    let icon: String
    let title: String
    let message: String
    var showSettings = false
    var showRetry = false
    var onRetry: (() -> Void)?
    var diagnostic: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.primaryGradient)

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // `openSettingsURLString` is the only App-Store-safe entry point into
                // Settings; it cannot target the Apple Intelligence pane (the `App-prefs:`
                // deep links that could are private API and a 2.5.1 rejection, and there is
                // no public system UI for the opt-in). Verified on device: this lands on
                // Flirty's *own* pane, which has no Apple Intelligence toggle — so `message`
                // must tell the user to back out to the Settings root from there.
                if showSettings, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(settingsURL) }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppTheme.primaryGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if showRetry, let onRetry {
                    Button("Try Again") { onRetry() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                }

                #if DEBUG
                if let diagnostic {
                    Text(diagnostic)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                }
                #endif
            }
        }
    }
}
