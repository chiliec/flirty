import SwiftUI

struct ProfileNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: WomanProfile

    @State private var newNote = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Avatar
                    Text(profile.initial)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.avatarGradient(for: profile.gradientIndex))
                        .clipShape(Circle())
                        .padding(.top, 16)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("Name", text: $profile.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)

                    // Notes section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes about her")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)

                        // Existing notes
                        ForEach(Array(profile.notes.enumerated()), id: \.offset) { index, note in
                            HStack {
                                Text(note)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Button {
                                    profile.notes.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Add new note
                        HStack(spacing: 8) {
                            TextField("Add a note...", text: $newNote)
                                .textFieldStyle(.plain)
                                .accessibilityIdentifier("addNoteField")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(10)
                                .background(AppTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onSubmit { addNote() }

                            Button {
                                addNote()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.violet)
                            }
                            .buttonStyle(.plain)
                            .disabled(newNote.isEmpty)
                            .accessibilityIdentifier("addNoteButton")
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.violet)
                }
            }
        }
    }

    private func addNote() {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profile.notes.append(trimmed)
        newNote = ""
    }
}

#Preview {
    ProfileNotesView(profile: WomanProfile(name: "Anna", gradientIndex: 0, notes: ["loves hiking", "has a cat named Milo"]))
        .modelContainer(for: [WomanProfile.self, Conversation.self], inMemory: true)
}
