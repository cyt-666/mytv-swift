import SwiftUI

enum MoviePilotResourceSearchButtonPresentation {
    case hero
    case compact
}

struct MoviePilotResourceSearchButton: View {
    let target: MoviePilotMediaTarget
    var seasonNumber: Int?
    var episodeNumber: Int?
    var presentation: MoviePilotResourceSearchButtonPresentation = .hero
    var onDownloaded: (() -> Void)?

    @State private var isShowingSearch = false

    var body: some View {
        Group {
            if target.tmdbId != nil,
               (try? MoviePilotSettingsStore.currentConfiguration()) != nil {
                Button {
                    isShowingSearch = true
                } label: {
                    switch presentation {
                    case .hero:
                        Label("搜索资源", systemImage: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.blue.gradient)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.26), radius: 10, y: 5)
                    case .compact:
                        Label("搜索资源", systemImage: "magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .fixedSize()
                .sheet(isPresented: $isShowingSearch) {
                    MoviePilotResourceSearchSheet(
                        target: target,
                        preferredSeason: seasonNumber,
                        preferredEpisode: episodeNumber,
                        onDownloaded: onDownloaded
                    )
                }
            }
        }
    }
}

struct MoviePilotResourceSearchSheet: View {
    let target: MoviePilotMediaTarget
    let preferredSeason: Int?
    let preferredEpisode: Int?
    let onDownloaded: (() -> Void)?

    @State private var viewModel: MoviePilotResourceSearchViewModel
    @State private var pendingDownload: MoviePilotTorrentSearchResult?
    @Environment(\.dismiss) private var dismiss

    init(
        target: MoviePilotMediaTarget,
        preferredSeason: Int? = nil,
        preferredEpisode: Int? = nil,
        onDownloaded: (() -> Void)? = nil
    ) {
        self.target = target
        self.preferredSeason = preferredSeason
        self.preferredEpisode = preferredEpisode
        self.onDownloaded = onDownloaded
        _viewModel = State(
            initialValue: MoviePilotResourceSearchViewModel(
                target: target,
                preferredSeason: preferredSeason,
                preferredEpisode: preferredEpisode
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                if viewModel.isSearching && viewModel.summary == nil {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.summary == nil {
                    errorView(error)
                } else {
                    resultsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 860, idealWidth: 920, minHeight: 620, idealHeight: 700)
        .task { await viewModel.search() }
        .confirmationDialog(
            "确认添加下载任务",
            isPresented: Binding(
                get: { pendingDownload != nil },
                set: { if !$0 { pendingDownload = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("添加到 MoviePilot") {
                guard let result = pendingDownload else { return }
                pendingDownload = nil
                Task {
                    if await viewModel.download(result) {
                        onDownloaded?()
                    }
                }
            }
            Button("取消", role: .cancel) {
                pendingDownload = nil
            }
        } message: {
            if let result = pendingDownload {
                Text(downloadConfirmation(for: result))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text("搜索 MoviePilot 资源")
                    .font(.system(size: 20, weight: .bold))
                HStack(spacing: 7) {
                    Text(target.title)
                        .foregroundStyle(.secondary)
                    if let code = viewModel.preferredEpisodeCode {
                        Text(code)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if let sourceText = viewModel.resultSourceText {
                        Text(sourceText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(viewModel.isUsingCachedResults ? .blue : .secondary)
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }

            Spacer()

            Button {
                Task { await viewModel.search(forceRefresh: true) }
            } label: {
                Label(viewModel.isSearching ? "搜索中" : "重新搜索", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isSearching || viewModel.downloadingReference != nil)

            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("MoviePilot 正在搜索已配置站点…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("资源搜索不可用", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("重新搜索") {
                Task { await viewModel.search(forceRefresh: true) }
            }
        }
    }

    private var resultsContent: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()

            if viewModel.isLoadingPage {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sortedResults.isEmpty {
                ContentUnavailableView(
                    "没有符合条件的资源",
                    systemImage: "tray",
                    description: Text("调整筛选条件或重新搜索。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.sortedResults) { result in
                            torrentRow(result)
                        }
                    }
                    .padding(16)
                }
            }

            Divider()
            footer
        }
    }

    private var filterBar: some View {
        let options = viewModel.summary?.filterOptions ?? .empty
        return HStack(spacing: 8) {
            SearchFilterMenu(title: "站点", options: options.site, selection: $viewModel.filters.sites)
            SearchFilterMenu(title: "季集", options: options.season, selection: $viewModel.filters.seasons)
            SearchFilterMenu(title: "促销", options: options.freeState, selection: $viewModel.filters.freeStates)
            SearchFilterMenu(title: "分辨率", options: options.resolution, selection: $viewModel.filters.resolutions)
            SearchFilterMenu(title: "编码", options: options.videoCode, selection: $viewModel.filters.videoCodes)
            SearchFilterMenu(title: "版本", options: options.edition, selection: $viewModel.filters.editions)
            SearchFilterMenu(title: "发布组", options: options.releaseGroup, selection: $viewModel.filters.releaseGroups)

            Spacer()

            Button("应用") {
                Task { await viewModel.applyFilters() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoadingPage)

            Button("重置") {
                Task { await viewModel.resetFilters() }
            }
            .disabled(viewModel.filters.isEmpty || viewModel.isLoadingPage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func torrentRow(_ result: MoviePilotTorrentSearchResult) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(.blue.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text(result.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    metadata(result.torrentInfo?.siteName, icon: "globe")
                    metadata(result.torrentInfo?.size, icon: "externaldrive")
                    if let seeders = result.torrentInfo?.seeders {
                        metadata("\(seeders) 做种", icon: "arrow.up.circle")
                    }
                    metadata(result.metaInfo?.resourceResolution, icon: "rectangle.inset.filled")
                    metadata(result.metaInfo?.videoEncode, icon: "video")
                    metadata(result.torrentInfo?.volumeFactor, icon: "tag")
                }
            }

            Spacer(minLength: 12)

            Button {
                pendingDownload = result
            } label: {
                if viewModel.downloadingReference == result.torrentInfo?.torrentURL {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("下载", systemImage: "arrow.down.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.downloadingReference != nil || result.torrentInfo?.torrentURL == nil)
        }
        .padding(13)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    @ViewBuilder
    private func metadata(_ value: String?, icon: String) -> some View {
        if let value, !value.isEmpty {
            Label(value, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var footer: some View {
        HStack {
            if let message = viewModel.message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            } else if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else {
                Text("共 \(viewModel.page.totalCount) 条资源")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { try? await viewModel.loadPage(viewModel.page.page - 1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(viewModel.page.page <= 1 || viewModel.isLoadingPage)

            Text("\(max(viewModel.page.page, 1)) / \(max(viewModel.page.totalPages, 1))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))

            Button {
                Task { try? await viewModel.loadPage(viewModel.page.page + 1) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(
                viewModel.page.totalPages == 0 ||
                viewModel.page.page >= viewModel.page.totalPages ||
                viewModel.isLoadingPage
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func downloadConfirmation(for result: MoviePilotTorrentSearchResult) -> String {
        let info = result.torrentInfo
        return [
            result.displayTitle,
            info?.siteName,
            info?.size,
            "将使用 MoviePilot 默认下载器和保存目录。"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}

private struct SearchFilterMenu: View {
    let title: String
    let options: [String]
    @Binding var selection: Set<String>

    var body: some View {
        if !options.isEmpty {
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        if selection.contains(option) {
                            selection.remove(option)
                        } else {
                            selection.insert(option)
                        }
                    } label: {
                        Label(
                            option,
                            systemImage: selection.contains(option) ? "checkmark" : ""
                        )
                    }
                }
            } label: {
                Text(selection.isEmpty ? title : "\(title) \(selection.count)")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
