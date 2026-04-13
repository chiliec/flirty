import SwiftUI

struct ResponseBubble: View {
    let tone: Tone
    let responseText: String
    let isStreaming: Bool
    var onCopy: () -> Void
    var onRegenerate: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tone label
            HStack(spacing: 4) {
                Image(systemName: tone.icon)
                    .font(.system(size: 10))
                Text("\(tone.displayName) response:")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(AppTheme.pink)

            // Response text
            Text(responseText)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(4)
                .textSelection(.enabled)

            // Action buttons
            if !isStreaming {
                HStack(spacing: 8) {
                    Button {
                        onCopy()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackground)
                        .foregroundStyle(AppTheme.violet)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onRegenerate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                            Text("Regenerate")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackground)
                        .foregroundStyle(AppTheme.pink)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.102, green: 0.102, blue: 0.227),
                    Color(red: 0.165, green: 0.102, blue: 0.227)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.violet.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        ResponseBubble(
            tone: .sweet,
            responseText: "My day was actually really great — had one of those meetings where everything just clicks. But honestly, the best part of my evening is reading your message. How about we check out that cafe this Saturday? 😊",
            isStreaming: false,
            onCopy: {},
            onRegenerate: {}
        )
        .padding()
    }
}
