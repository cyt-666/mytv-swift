import SwiftUI

struct SearchView: View {
    let query: String
    @State private var viewModel = SearchViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && viewModel.results.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.results.isEmpty {
                    ContentUnavailableView {
                        Text(errorMessage)
                    } actions: {
                        Button("重试") {
                            Task { await viewModel.load(query: query, reset: true) }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView(
                        "未找到结果",
                        systemImage: "magnifyingglass",
                        description: Text("尝试其他关键词")
                    )
                } else {
                    MediaGridView(
                        items: viewModel.results,
                        onItemAppear: { item in
                            Task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    PaginationFooterView(
                        isLoadingMore: viewModel.isLoadingMore,
                        canLoadMore: viewModel.canLoadMore,
                        errorMessage: viewModel.errorMessage,
                        onRetry: {
                            Task { await viewModel.loadMoreIfNeeded() }
                        }
                    )
                }
            }
        }
        .task(id: query) {
            await viewModel.load(query: query, reset: true)
        }
    }
}
