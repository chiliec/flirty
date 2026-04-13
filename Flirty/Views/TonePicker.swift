import SwiftUI

struct TonePicker: View {
    @Binding var selectedTone: Tone

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Tone.allCases) { tone in
                    tonePill(tone)
                }
            }
        }
    }

    private func tonePill(_ tone: Tone) -> some View {
        let isSelected = selectedTone == tone

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTone = tone
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tone.icon)
                    .font(.system(size: 11))
                Text(tone.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(AppTheme.primaryGradient.opacity(0.2))
                    : AnyShapeStyle(AppTheme.cardBackground)
            )
            .foregroundStyle(isSelected ? AppTheme.pink : AppTheme.textMuted)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? AppTheme.pink.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        TonePicker(selectedTone: .constant(.sweet))
            .padding()
    }
}
