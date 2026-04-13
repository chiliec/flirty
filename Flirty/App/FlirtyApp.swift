import SwiftUI
import SwiftData

@main
struct FlirtyApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Flirty")
        }
        .modelContainer(for: [WomanProfile.self, Conversation.self])
    }
}
