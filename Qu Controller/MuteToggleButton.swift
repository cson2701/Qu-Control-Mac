import SwiftUI

struct MuteToggleButton: View {
    let isMuted: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isMuted ? Color.white : Color.primary)
                .frame(minWidth: 34)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(backgroundShape)
        }
        .buttonStyle(.plain)
    }

    private var backgroundShape: some View {
        Capsule(style: .continuous)
            .fill(isMuted ? Color.red : Color(nsColor: .controlBackgroundColor))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isMuted ? Color.red.opacity(0.9) : Color.primary.opacity(0.14),
                        lineWidth: 1
                    )
            )
    }
}
