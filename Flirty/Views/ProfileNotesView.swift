import SwiftUI

struct ProfileNotesView: View {
    @Bindable var profile: WomanProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                Text("Notes for \(profile.name)")
                    .foregroundStyle(AppTheme.textPrimary)
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
}
