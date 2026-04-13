import SwiftUI
import SwiftData

struct AddWomanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var firstNote = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Avatar preview
                    Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(AppTheme.primaryGradient)
                        .clipShape(Circle())
                        .padding(.top, 20)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("Her name", text: $name)
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

                    // Optional first note
                    VStack(alignment: .leading, spacing: 6) {
                        Text("First note (optional)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("e.g., loves hiking, works in design", text: $firstNote)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(name.isEmpty ? AppTheme.textMuted : AppTheme.violet)
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let notes = firstNote.isEmpty ? [] : [firstNote]
        let gradientIndex = Int.random(in: 0..<AppTheme.avatarGradients.count)
        let profile = WomanProfile(name: name.trimmingCharacters(in: .whitespaces), gradientIndex: gradientIndex, notes: notes)
        modelContext.insert(profile)
        dismiss()
    }
}

#Preview {
    AddWomanView()
        .modelContainer(for: [WomanProfile.self, Conversation.self], inMemory: true)
}
