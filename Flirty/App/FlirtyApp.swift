import SwiftUI
import SwiftData

@main
struct FlirtyApp: App {
    var body: some Scene {
        WindowGroup {
            WomenListView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [WomanProfile.self, Conversation.self])
    }
}
