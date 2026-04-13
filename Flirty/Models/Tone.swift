import Foundation

enum Tone: String, Codable, CaseIterable, Identifiable {
    case flirty
    case sweet
    case funny
    case poetic
    case caring

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .flirty: "flame.fill"
        case .sweet: "heart.fill"
        case .funny: "face.smiling.fill"
        case .poetic: "sparkles"
        case .caring: "hands.and.sparkles.fill"
        }
    }

    var modifier: String {
        switch self {
        case .flirty: "Be playfully confident. Light teasing is good. Add subtle tension."
        case .sweet: "Be warm and affectionate. Show you care about the details she shares."
        case .funny: "Be witty and lighthearted. Use humor naturally, not forced jokes."
        case .poetic: "Be expressive and eloquent. Use vivid language and metaphors sparingly."
        case .caring: "Be supportive and attentive. Show empathy and genuine interest in her feelings."
        }
    }
}
