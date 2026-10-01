import PhotosUI
import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: WomanProfile

    @State private var screenshotItem: PhotosPickerItem?
    @State private var herMessage = ""
    @State private var userContext = ""
    @State private var selectedTone: Tone = .sweet
    @State private var currentResponse = ""
    @State private var isGenerating = false
    @State private var showingNotes = false
    @State private var showError = false
    @State private var errorMessage = ""

    @State private var aiService = AIService()

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        conversationHistory
                        // The live reply sits right under her message in the history,
                        // reading like a chat; the input below is for the next round.
                        if !currentResponse.isEmpty || isGenerating {
                            responseArea
                        }
                        inputArea
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .onChange(of: currentResponse) {
                    withAnimation {
                        scrollProxy.scrollTo("bottom")
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }

            // Screenshot runs (stubbed reply) never summarize, so the label is noise there.
            if isUITesting, ProcessInfo.processInfo.environment["FLIRTY_STUB_RESPONSE"] == nil {
                summaryDiagnostic
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text(profile.initial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.avatarGradient(for: profile.gradientIndex))
                        .clipShape(Circle())
                    Text(profile.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNotes = true
                } label: {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.violet)
                }
                .accessibilityIdentifier("notesButton")
            }
        }
        .sheet(isPresented: $showingNotes) {
            ProfileNotesView(profile: profile)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            aiService.prewarm()
        }
    }

    // MARK: - Summarization Diagnostic

    /// `conversationSummary` and `summarizedExchangeCount` drive the whole token budget but
    /// never reach the UI, so on a device they are only observable in a debugger — and the
    /// summarization path cannot be exercised on the simulator at all. This renders them
    /// under `--ui-testing` only, so `DeviceAIGenerationTests` can assert on them.
    ///
    /// It sits in the ZStack rather than the scrolling stack deliberately: after five
    /// exchanges the top of the history has scrolled away, and the test must still be able
    /// to read the current values.
    private var summaryDiagnostic: some View {
        Text(summaryDiagnosticText)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(AppTheme.textMuted)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .allowsHitTesting(false)
            .accessibilityIdentifier("summaryDiagnostic")
    }

    /// A whole label the test can compare for equality: the count proves aged-out exchanges
    /// were tracked, and the summary text itself follows so a test can tell "did not
    /// re-summarize" apart from "re-summarized to something similar", and can check that
    /// content from a summarized-away exchange actually survived. Only the *display* is
    /// truncated to one line — the accessibility label carries the full string.
    private var summaryDiagnosticText: String {
        let summary = profile.conversationSummary ?? ""
        return "summarized:\(profile.summarizedExchangeCount) summary:\(summary)"
    }

    // MARK: - Conversation History

    /// The saved exchange whose reply is currently shown in `ResponseBubble`; its history
    /// copy is hidden so the same text is not on screen twice.
    private var echoedConversationID: UUID? {
        guard !currentResponse.isEmpty, let last = profile.sortedConversations.last,
            last.generatedResponse == currentResponse
        else { return nil }
        return last.id
    }

    private func delete(_ conversation: Conversation) {
        // Keep the stored summary's coverage count honest when a folded-in exchange goes.
        if let index = profile.sortedConversations.firstIndex(where: { $0.id == conversation.id }),
            index < profile.summarizedExchangeCount
        {
            profile.summarizedExchangeCount -= 1
        }
        if conversation.id == echoedConversationID {
            currentResponse = ""
        }
        modelContext.delete(conversation)
    }

    private var conversationHistory: some View {
        ForEach(profile.sortedConversations) { conversation in
            VStack(alignment: .leading, spacing: 8) {
                // Her message
                VStack(alignment: .leading, spacing: 2) {
                    Text("Her:")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                    Text(conversation.herMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(10)
                        .background(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Your response
                if conversation.id != echoedConversationID {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: conversation.tone.icon)
                                .font(.system(size: 9))
                            Text("Your \(conversation.tone.displayName.lowercased()) reply:")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(AppTheme.textMuted)

                        Text(conversation.generatedResponse)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(10)
                            .background(AppTheme.violet.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.bottom, 4)
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(conversation)
                }
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 12) {
            // Her message input
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Her message:")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                    Spacer()
                    // A chat screenshot is how most people have her message; Vision reads
                    // it on device. The picker is privacy-preserving, no photo permission.
                    PhotosPicker(selection: $screenshotItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.violet)
                    }
                    .accessibilityIdentifier("screenshotButton")
                    .onChange(of: screenshotItem) {
                        Task { await readScreenshot() }
                    }
                    // The main flow is copy from Messages, paste here: one tap instead of
                    // tap-hold-Paste. The system button only enables when text is on the
                    // clipboard and reads it without the paste permission banner.
                    PasteButton(payloadType: String.self) { strings in
                        guard let text = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                            !text.isEmpty
                        else { return }
                        herMessage = text
                    }
                    .labelStyle(.iconOnly)
                    .controlSize(.mini)
                    .buttonBorderShape(.capsule)
                    .tint(AppTheme.violet)
                    .accessibilityIdentifier("pasteButton")
                }
                TextField("Paste her message here...", text: $herMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("herMessageField")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1...6)
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Tone picker
            TonePicker(selectedTone: $selectedTone)

            // User context input
            TextField("Add real context... (optional)", text: $userContext)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("userContextField")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(12)
                .background(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Generate button
            Button {
                Task { await generateResponse() }
            } label: {
                HStack(spacing: 6) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                    }
                    Text(isGenerating ? "Generating..." : "Generate Response")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    if herMessage.isEmpty || isGenerating {
                        AppTheme.cardBackground
                    } else {
                        AppTheme.primaryGradient
                    }
                }
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(herMessage.isEmpty || isGenerating)
            .accessibilityIdentifier("generateButton")
        }
    }

    // MARK: - Response Area

    private var responseArea: some View {
        ResponseBubble(
            tone: selectedTone,
            responseText: currentResponse.isEmpty ? "Thinking..." : currentResponse,
            isStreaming: isGenerating,
            onCopy: {
                UIPasteboard.general.string = currentResponse
            },
            onRegenerate: {
                Task { await regenerateLastResponse() }
            }
        )
    }

    // MARK: - Screenshot

    private func readScreenshot() async {
        guard let item = screenshotItem else { return }
        screenshotItem = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let text = try await ScreenshotReader.text(in: data)
            guard !text.isEmpty else {
                errorMessage = "No text found in that image."
                showError = true
                return
            }
            herMessage = text
        } catch {
            errorMessage = "Couldn't read that image: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Generation

    private func generateResponse() async {
        let messageText = herMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }

        isGenerating = true
        currentResponse = ""

        let profileData = WomanProfileData(
            name: profile.name,
            notes: profile.notes,
            conversationSummary: profile.conversationSummary,
            summarizedExchangeCount: profile.summarizedExchangeCount,
            exchanges: profile.sortedConversations.map {
                ContextManager.Exchange(herMessage: $0.herMessage, response: $0.generatedResponse)
            }
        )

        let contextText = userContext.isEmpty ? nil : userContext

        do {
            let finalResponse = try await aiService.generate(
                profile: profileData,
                herMessage: messageText,
                userContext: contextText,
                tone: selectedTone,
                onUpdate: { partial in
                    currentResponse = partial
                },
                onSummaryProduced: { summary, summarizedCount in
                    profile.conversationSummary = summary
                    profile.summarizedExchangeCount = summarizedCount
                }
            )

            // Save the conversation
            let conversation = Conversation(
                herMessage: messageText,
                userContext: contextText,
                tone: selectedTone,
                generatedResponse: finalResponse
            )
            conversation.womanProfile = profile
            modelContext.insert(conversation)

            // Clear inputs for next round
            herMessage = ""
            userContext = ""

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isGenerating = false
    }

    /// Regeneration cannot route through `generateResponse()`: that reads `herMessage`,
    /// which is cleared on success, so the button did nothing at all once a response had
    /// landed — and had the guard passed it would have inserted a *second* `Conversation`
    /// for the same message instead of replacing the reply. Replay the last exchange and
    /// overwrite its response in place, which is what the button promises.
    private func regenerateLastResponse() async {
        guard let target = profile.sortedConversations.last else { return }

        isGenerating = true
        currentResponse = ""

        // Drop the exchange being replaced from the history, or the model is primed with
        // the very answer it is meant to reconsider.
        let history = profile.sortedConversations
            .filter { $0.id != target.id }
            .map { ContextManager.Exchange(herMessage: $0.herMessage, response: $0.generatedResponse) }

        let profileData = WomanProfileData(
            name: profile.name,
            notes: profile.notes,
            conversationSummary: profile.conversationSummary,
            summarizedExchangeCount: profile.summarizedExchangeCount,
            exchanges: history
        )

        do {
            let finalResponse = try await aiService.generate(
                profile: profileData,
                herMessage: target.herMessage,
                userContext: target.userContext,
                tone: selectedTone,
                onUpdate: { partial in
                    currentResponse = partial
                },
                onSummaryProduced: { summary, summarizedCount in
                    profile.conversationSummary = summary
                    profile.summarizedExchangeCount = summarizedCount
                }
            )

            // Regenerate honours the tone picker as it stands now, so a user can retry the
            // same message in a different tone. Keep the stored tone in step with the text.
            target.generatedResponse = finalResponse
            target.toneRawValue = selectedTone.rawValue

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isGenerating = false
    }
}

#Preview {
    NavigationStack {
        ChatView(profile: {
            let p = WomanProfile(name: "Anna", gradientIndex: 0, notes: ["loves hiking", "has a cat named Milo"])
            return p
        }())
    }
    .modelContainer(for: [WomanProfile.self, Conversation.self], inMemory: true)
}
