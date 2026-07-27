import SwiftUI

struct WatchlistView: View {
    @State private var viewModel = WatchlistViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isCompact {
                    sourcePicker
                        .padding(.horizontal, 16)
                }

                filterBar
                    .padding(.horizontal, isCompact ? 16 : 20)

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                    ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle", description: Text("请稍后重试或检查 Trakt 登录状态"))
                        .padding(.top, 36)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(viewModel.emptyTitle, systemImage: viewModel.source == .customList ? "list.bullet.rectangle" : "bookmark", description: Text(viewModel.emptyDescription))
                        .padding(.top, 36)
                } else {
                    MediaGridView(items: viewModel.items) { _ in }
                        .padding(.horizontal, isCompact ? 16 : 20)
                }
            }
            .padding(.top, 24)
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.source) { _, _ in
            Task { await viewModel.load() }
        }
        .onChange(of: viewModel.mediaType) { _, _ in Task { await viewModel.load() } }
        .onChange(of: viewModel.selectedListId) { _, _ in
            guard viewModel.source == .customList else { return }
            Task { await viewModel.load() }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !isCompact {
                    sourcePicker
                        .frame(width: 190)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading)
                .help("刷新")
            }
        }
    }

    private var sourcePicker: some View {
        Picker("列表来源", selection: $viewModel.source) {
            ForEach(WatchlistViewModel.Source.allCases, id: \.self) { source in
                Text(source.title).tag(source)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.regular)
        .labelsHidden()
    }

    private var filterBar: some View {
        HStack(spacing: isCompact ? 12 : 16) {
            if viewModel.source == .customList {
                customListMenu
                if viewModel.selectedListId != nil, !viewModel.customLists.isEmpty {
                    mediaTypeMenu
                }
            } else {
                mediaTypeMenu
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediaTypeMenu: some View {
        Menu {
            Button {
                viewModel.mediaType = "movies"
            } label: {
                Label("电影", systemImage: "film")
            }

            Button {
                viewModel.mediaType = "shows"
            } label: {
                Label("剧集", systemImage: "tv")
            }
        } label: {
            inlineMenuLabel(
                title: viewModel.mediaType == "movies" ? L10n.string("电影") : L10n.string("剧集"),
                icon: viewModel.mediaType == "movies" ? "film" : "tv"
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private var customListMenu: some View {
        Menu {
            if viewModel.customLists.isEmpty {
                Text("暂无列表")
            } else {
                ForEach(viewModel.customLists) { list in
                    Button {
                        viewModel.selectedListId = list.ids.trakt
                    } label: {
                        Text(list.name)
                    }
                }
            }
        } label: {
            inlineMenuLabel(
                title: viewModel.customListTitle(for: viewModel.selectedListId),
                icon: "list.bullet.rectangle"
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(viewModel.customLists.isEmpty)
    }

    private func inlineMenuLabel(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
