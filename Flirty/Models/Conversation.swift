import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var herMessage: String
    var userContext: String?
    var toneRawValue: String
    var generatedResponse: String
    var createdAt: Date

    var womanProfile: WomanProfile?

    init(herMessage: String, userContext: String?, tone: Tone, generatedResponse: String) {
        self.id = UUID()
        self.herMessage = herMessage
        self.userContext = userContext
        self.toneRawValue = tone.rawValue
        self.generatedResponse = generatedResponse
        self.createdAt = Date()
    }

    var tone: Tone {
        get { Tone(rawValue: toneRawValue) ?? .sweet }
        set { toneRawValue = newValue.rawValue }
    }
}
