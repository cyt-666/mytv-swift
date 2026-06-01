import SwiftUI

struct MediaGridView: View {
    let items: [MediaItem]
    var onItemTap: ((MediaItem) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(items) { item in
                MediaCardView(item: item)
            }
        }
    }
}
