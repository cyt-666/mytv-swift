import SwiftUI

struct MoviesView: View {
    @State private var viewModel = MoviesViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else {
                    MediaGridView(items: viewModel.items.map { .movie($0) }) { _ in }
                        .padding(.horizontal, 20)

                    loadMoreTrigger
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
                Picker("电影分类", selection: $viewModel.selectedTab) {
                    Text("热门").tag(MoviesViewModel.Tab.trending)
                    Text("流行").tag(MoviesViewModel.Tab.popular)
                    Text("即将上映").tag(MoviesViewModel.Tab.anticipated)
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                .labelsHidden()
                .frame(width: 270)
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

    private var loadMoreTrigger: some View {
        Group {
            if viewModel.canLoadMore {
                HStack {
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .opacity(0)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .onAppear {
                    Task { await viewModel.loadMoreIfNeeded() }
                }
            }
        }
    }
}
