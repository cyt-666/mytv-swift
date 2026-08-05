import SwiftUI

struct MoviePilotEpisodeStateBadge: View {
    let state: MoviePilotEpisodeState

    var body: some View {
        Label(state.displayName, systemImage: state.systemImage)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.13))
            .clipShape(Capsule())
    }

    private var tint: Color {
        switch state {
        case .inLibrary: return .green
        case .downloading: return .blue
        case .pendingLibrary: return .purple
        case .unaired: return .secondary
        case .subscribed: return .orange
        case .missing: return .red
        }
    }
}
