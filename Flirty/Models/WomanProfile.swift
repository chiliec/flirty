import Foundation
import SwiftData

@Model
final class WomanProfile {
    var id: UUID
    var name: String
    var gradientIndex: Int
    var notes: [String]
    var conversationSummary: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Conversation.womanProfile)
    var conversations: [Conversation]

    init(name: String, gradientIndex: Int, notes: [String] = []) {
        self.id = UUID()
        self.name = name
        self.gradientIndex = gradientIndex
        self.notes = notes
        self.conversationSummary = nil
        self.createdAt = Date()
        self.conversations = []
    }

    var initial: String {
        String(name.prefix(1)).uppercased()
    }

    var sortedConversations: [Conversation] {
        conversations.sorted { $0.createdAt < $1.createdAt }
    }

    var notesPreview: String {
        if notes.isEmpty { return "No notes yet" }
        return notes.joined(separator: ", ")
    }
}
