import SwiftUI

struct ChatView: View {
    let profile: WomanProfile

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            Text("Chat with \(profile.name)")
                .foregroundStyle(AppTheme.textPrimary)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
