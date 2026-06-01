import SwiftUI

struct RatingBadgeView: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 9))
            Text(String(format: "%.1f", rating))
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
