import SwiftUI
import SwiftData

@main
struct FlirtyApp: App {
    @State private var aiService = AIService()

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
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

    var body: some View {
        Group {
            if let availability {
                switch availability {
                case .available:
                    WomenListView()
                case .notEnabled:
                    UnavailableView(
                        icon: "brain",
                        title: "Apple Intelligence Required",
                        message: "Enable Apple Intelligence in Settings → Apple Intelligence & Siri to use Flirty.",
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
                        message: "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri, then wait for the model to finish downloading.",
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
    }

    private func checkAvailability() {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            availability = .available
        } else {
            availability = aiService.checkAvailability()
            diagnostic = aiService.availabilityDiagnostic
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
                // deep links that could are private API and a 2.5.1 rejection). So the
                // button gets the user into Settings and `message` covers the last hop.
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
