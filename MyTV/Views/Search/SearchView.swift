import SwiftUI

struct SearchView: View {
    let query: String
    @State private var viewModel = SearchViewModel()
    @State private var searchText: String

    init(query: String) {
        self.query = query
        _searchText = State(initialValue: query)
    }

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
                        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "搜索电影和剧集" : "未找到结果",
                        systemImage: "magnifyingglass",
                        description: Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "输入片名、剧名或演员关键词" : "尝试其他关键词")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    MediaGridView(
                        items: viewModel.results,
                        onItemAppear: { item in
                            Task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

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
        .navigationTitle("搜索")
        .platformSearchable(text: $searchText, prompt: "搜索电影、剧集")
        .onSubmit(of: .search) {
            Task { await viewModel.load(query: searchText, reset: true) }
        }
        .task(id: query) {
            searchText = query
            await viewModel.load(query: query, reset: true)
        }
    }
}

private extension View {
    @ViewBuilder
    func platformSearchable(text: Binding<String>, prompt: String) -> some View {
        #if os(iOS)
        searchable(
            text: text,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(prompt)
        )
        #else
        searchable(text: text, prompt: Text(prompt))
        #endif
    }
}
