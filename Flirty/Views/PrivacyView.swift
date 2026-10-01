import SwiftUI

/// The in-app copy of PRIVACY.md, reachable from the list toolbar. Keep the two in sync.
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        section(
                            "On your iPhone", icon: "lock.shield.fill",
                            "On iPhones with Apple Intelligence, every reply is written on your device. Her messages, your notes and the replies never leave your phone. Screenshots are read on device too; the image is never stored or sent."
                        )
                        section(
                            "Cloud mode", icon: "icloud.fill",
                            "On iPhones without Apple Intelligence, Flirty can use a cloud model instead. It stays off until you allow it. When on, only the text needed to write the reply (including text read from a screenshot) is sent over HTTPS to the Flirty gateway, which forwards it to Anthropic's Claude. Nothing is stored. Turn it off any time from the cloud icon."
                        )
                        section(
                            "Stored locally", icon: "iphone",
                            "Profiles, notes and history live on your device only. Never synced, never uploaded. Deleting a profile deletes its history."
                        )
                        section(
                            "No tracking", icon: "eye.slash.fill",
                            "No account, no analytics, no telemetry."
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.violet)
                }
            }
        }
    }

    private func section(_ title: String, icon: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.primaryGradient)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
