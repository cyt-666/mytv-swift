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
                browseControls
                    .padding(.horizontal, isCompact ? 16 : 20)

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
                        items: viewModel.items,
                        onItemAppear: { item in
                            Task { await viewModel.loadMoreIfNeeded(currentItem: item) }
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
        .onChange(of: viewModel.selectedMediaType) { _, _ in
            viewModel.prepareForMediaTypeChange()
            Task { await viewModel.load(reset: true) }
        }
        .onChange(of: viewModel.selectedGenre) { _, _ in Task { await viewModel.load(reset: true) } }
        .onChange(of: viewModel.selectedCountry) { _, _ in Task { await viewModel.load(reset: true) } }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !isCompact {
                    mediaTypePicker
                        .frame(width: 180)
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

    @ViewBuilder
    private var browseControls: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 12) {
                mediaTypePicker
                    .frame(maxWidth: .infinity)
                filterFields
            }
        } else {
            filterFields
        }
    }

    private var mediaTypePicker: some View {
        Picker(L10n.string("媒体类型"), selection: $viewModel.selectedMediaType) {
            ForEach(BrowseMediaType.allCases) { mediaType in
                Text(mediaType.localizedTitle)
                    .tag(mediaType)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.regular)
        .labelsHidden()
        .accessibilityLabel(L10n.string("媒体类型"))
    }

    private var filterFields: some View {
        HStack(alignment: .bottom, spacing: 14) {
            filterField(title: "类型", systemImage: "theatermasks") {
                genrePicker
            }

            filterField(title: "国家", systemImage: "globe.asia.australia") {
                countryPicker
            }

            Spacer(minLength: 0)
            clearFiltersButton
        }
    }

    private func filterField<Content: View>(
        title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var genrePicker: some View {
        Picker("", selection: $viewModel.selectedGenre) {
            Text("全部类型").tag("")
            ForEach(viewModel.genres) { genre in
                Text(genre.localizedTitle).tag(genre.value)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.regular)
        .labelsHidden()
        .frame(minWidth: 132)
        .accessibilityLabel(L10n.string("类型"))
    }

    private var countryPicker: some View {
        Picker("", selection: $viewModel.selectedCountry) {
            Text("全部国家").tag("")
            ForEach(viewModel.countries) { country in
                Text(country.localizedTitle).tag(country.value)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.regular)
        .labelsHidden()
        .frame(minWidth: 132)
        .accessibilityLabel(L10n.string("国家"))
    }

    @ViewBuilder
    private var clearFiltersButton: some View {
        if viewModel.hasActiveFilters {
            Button {
                viewModel.clearFilters()
            } label: {
                Label("清除", systemImage: "xmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(L10n.string("清除筛选"))
            .accessibilityLabel(L10n.string("清除筛选"))
        }
    }
}
