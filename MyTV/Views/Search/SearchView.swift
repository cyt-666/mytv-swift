import SwiftUI

struct SearchView: View {
    let query: String
    @State private var viewModel = SearchViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView(
                        "未找到结果",
                        systemImage: "magnifyingglass",
                        description: Text("尝试其他关键词")
                    )
                } else {
                    MediaGridView(items: viewModel.results) { _ in }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                }
            }
        }
        .task {
            await viewModel.search(query: query)
        }
    }
}
