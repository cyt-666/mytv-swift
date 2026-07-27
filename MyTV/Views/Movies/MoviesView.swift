import SwiftUI

struct MoviesView: View {
    @State private var viewModel = MoviesViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isCompact {
                    categoryPicker
                        .padding(.horizontal, 16)
                }

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                    ContentUnavailableView {
                        Text(errorMessage)
                    } actions: {
                        Button("重试") {
                            Task { await viewModel.load() }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    MediaGridView(
                        items: viewModel.items.map { .movie($0) },
                        onItemAppear: { item in
                            guard case .movie(let movie) = item else { return }
                            Task { await viewModel.loadMoreIfNeeded(currentItem: movie) }
                        }
                    )
                    .padding(.horizontal, isCompact ? 16 : 20)

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
            .padding(.top, 24)
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.selectedTab) { _, _ in
            Task { await viewModel.load() }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !isCompact {
                    categoryPicker
                        .frame(width: 270)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { CacheService.clearAllAPIResponses(); await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading || viewModel.isLoadingMore)
                .help("刷新")
            }
        }
    }

    private var categoryPicker: some View {
        Picker("电影分类", selection: $viewModel.selectedTab) {
            Text("热门").tag(MoviesViewModel.Tab.trending)
            Text("流行").tag(MoviesViewModel.Tab.popular)
            Text("即将上映").tag(MoviesViewModel.Tab.anticipated)
        }
        .pickerStyle(.segmented)
        .controlSize(.regular)
        .labelsHidden()
    }
}
