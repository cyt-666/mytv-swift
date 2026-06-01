import SwiftUI

struct LoadingStateView: View {
    let isLoading: Bool
    let isEmpty: Bool
    let emptyTitle: String
    let emptyIcon: String
    let emptyDescription: String

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptyIcon,
                    description: Text(emptyDescription)
                )
            }
        }
    }
}
