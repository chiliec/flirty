import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let background = Color(red: 0.039, green: 0.039, blue: 0.059)       // #0a0a0f
    static let cardBackground = Color(red: 0.086, green: 0.086, blue: 0.165)    // #16162a
    static let cardBorder = Color(red: 0.165, green: 0.165, blue: 0.290)        // #2a2a4a
    static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)            // #a78bfa
    static let pink = Color(red: 0.925, green: 0.282, blue: 0.600)              // #ec4899
    static let textPrimary = Color(red: 0.886, green: 0.910, blue: 0.941)       // #e2e8f0
    static let textSecondary = Color(red: 0.580, green: 0.639, blue: 0.722)     // #94a3b8
    static let textMuted = Color(red: 0.392, green: 0.455, blue: 0.545)         // #64748b

    static let primaryGradient = LinearGradient(
        colors: [violet, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Avatar Gradients
    static let avatarGradients: [(Color, Color)] = [
        (Color(red: 0.957, green: 0.447, blue: 0.714), Color(red: 0.655, green: 0.545, blue: 0.980)), // pink → violet
        (Color(red: 0.204, green: 0.827, blue: 0.600), Color(red: 0.231, green: 0.510, blue: 0.965)), // green → blue
        (Color(red: 0.984, green: 0.749, blue: 0.141), Color(red: 0.976, green: 0.451, blue: 0.086)), // amber → orange
        (Color(red: 0.133, green: 0.827, blue: 0.933), Color(red: 0.388, green: 0.400, blue: 0.945)), // cyan → indigo
        (Color(red: 0.984, green: 0.443, blue: 0.522), Color(red: 0.937, green: 0.267, blue: 0.267)), // rose → red
    ]

    static func avatarGradient(for index: Int) -> LinearGradient {
        let pair = avatarGradients[index % avatarGradients.count]
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
