import SwiftUI

struct MediaRailView: View {
    let title: String
    let items: [MediaItem]
    var icon: String? = nil
    var iconColor: Color = .accentColor
    var onSeeAll: (() -> Void)?
    var leadingInset: CGFloat = 0
    var leadingBleed: CGFloat = 0
    var trailingInset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(.system(size: 20, weight: .bold))

                if onSeeAll != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onSeeAll?() }
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)

            // Scrolling rail
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(items) { item in
                        MediaCardView(item: item)
                    }
                }
                .padding(.leading, leadingBleed + leadingInset)
                .padding(.trailing, trailingInset)
            }
            .padding(.leading, -leadingBleed)
            .scrollClipDisabled()
        }
    }
}
