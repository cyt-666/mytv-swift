import SwiftUI

struct BrowseView: View {
    @State private var viewModel = BrowseViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isCompact {
                    filterControls
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
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "暂无结果",
                        systemImage: "square.grid.2x2",
                        description: Text("换一个类型或国家试试")
                    )
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
        .onChange(of: viewModel.selectedGenre) { _, _ in Task { await viewModel.load(reset: true) } }
        .onChange(of: viewModel.selectedCountry) { _, _ in Task { await viewModel.load(reset: true) } }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !isCompact {
                    filterControls
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { CacheService.clearAllAPIResponses(); await viewModel.load(reset: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading || viewModel.isLoadingMore)
                .help(L10n.string("刷新"))
            }
        }
    }

    private var filterControls: some View {
        HStack(spacing: 8) {
            Picker("类型", selection: $viewModel.selectedGenre) {
                Text("全部类型").tag("")
                ForEach(viewModel.genres) { genre in
                    Text(genre.localizedTitle).tag(genre.value)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.regular)

            Picker("国家", selection: $viewModel.selectedCountry) {
                Text("全部国家").tag("")
                ForEach(viewModel.countries) { country in
                    Text(country.localizedTitle).tag(country.value)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.regular)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
