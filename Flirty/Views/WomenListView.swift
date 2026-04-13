import SwiftUI
import SwiftData

struct WomenListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WomanProfile.createdAt, order: .reverse) private var profiles: [WomanProfile]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if profiles.isEmpty {
                    emptyState
                } else {
                    profileList
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Flirty")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryGradient)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Circle())
                    }
                    .accessibilityIdentifier("addProfileButton")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddWomanView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.primaryGradient)
            Text("No conversations yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityIdentifier("emptyStateTitle")
            Text("Tap + to add someone and start crafting\nthoughtful messages")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var profileList: some View {
        List {
            ForEach(profiles) { profile in
                NavigationLink(value: profile) {
                    profileCardContent(profile)
                }
                .listRowBackground(AppTheme.cardBackground)
                .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(profiles[index])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: WomanProfile.self) { profile in
            ChatView(profile: profile)
        }
    }

    private func profileCardContent(_ profile: WomanProfile) -> some View {
        HStack(spacing: 12) {
            Text(profile.initial)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppTheme.avatarGradient(for: profile.gradientIndex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(profile.notesPreview)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(profile.conversations.count) chats")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WomenListView()
        .modelContainer(for: [WomanProfile.self, Conversation.self], inMemory: true)
}
