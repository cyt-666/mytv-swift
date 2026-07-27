import SwiftUI

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if viewModel.isLoading && viewModel.groupedShows.isEmpty {
                    CalendarLoadingView()
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Text(error)
                    } actions: {
                        Button("重试") { Task { CacheService.clearAllAPIResponses(); await viewModel.load() } }
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else if viewModel.groupedShows.isEmpty {
                    ContentUnavailableView(
                        "暂无日程",
                        systemImage: "calendar",
                        description: Text("将剧集加入观看清单后，播出日历会显示在这里。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    CalendarHeroView(
                        rangeTitle: viewModel.rangeTitle,
                        totalCount: viewModel.totalEpisodeCount,
                        todayCount: viewModel.todayEpisodeCount
                    )

                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(viewModel.groupedShows) { group in
                            CalendarDaySection(group: group) { route in
                                appState.navigate(to: route)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.top, isCompact ? 18 : 56)
            .padding(.bottom, 36)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
        }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { CacheService.clearAllAPIResponses(); await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading)
                .help("刷新")
            }
        }
    }
}

private struct CalendarHeroView: View {
    let rangeTitle: String
    let totalCount: Int
    let todayCount: Int
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    metrics
                }
            } else {
                HStack(alignment: .center, spacing: 26) {
                    titleBlock
                    Spacer()
                    metrics
                }
            }
        }
        .padding(isCompact ? 20 : 28)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 164 : 172, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [.white.opacity(0.08), .blue.opacity(0.10), .orange.opacity(0.07)]
                        : [.white.opacity(0.52), .blue.opacity(0.08), .orange.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.11 : 0.08), lineWidth: 1)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rangeTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("剧集日历")
                .font(.system(size: isCompact ? 30 : 36, weight: .bold))
                .foregroundStyle(.primary)

            Text("追踪观看清单中即将播出的单集")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            CalendarSummaryMetric(title: "未来日程", value: "\(totalCount)", unit: "集")
            CalendarSummaryMetric(title: "今日更新", value: "\(todayCount)", unit: "集")
        }
    }
}

private struct CalendarSummaryMetric: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                Text(unit)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 112, alignment: .leading)
    }
}

private struct CalendarDaySection: View {
    let group: CalendarGroup
    let onSelect: (Route) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(group.relativeTitle)
                            .font(.system(size: 22, weight: .bold))
                        if group.isToday {
                            Text("今天")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.orange.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(group.monthDay) \(group.weekday)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(group.shows.count) 集")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            LazyVStack(spacing: 14) {
                ForEach(group.shows) { show in
                    CalendarEpisodeButton(show: show, onSelect: onSelect)
                }
            }
        }
    }
}

private struct CalendarEpisodeButton: View {
    let show: CalendarShowDTO
    let onSelect: (Route) -> Void

    var body: some View {
        Button {
            onSelect(route)
        } label: {
            CalendarEpisodeCard(show: show)
        }
        .buttonStyle(.plain)
    }

    private var route: Route {
        if let episode = show.episode {
            return .episodeDetail(
                showId: show.show.ids.trakt,
                seasonNumber: episode.season,
                episodeNumber: episode.number
            )
        }
        return .showDetail(id: show.show.ids.trakt)
    }
}

private struct CalendarEpisodeCard: View {
    let show: CalendarShowDTO
    @State private var showTranslation: TranslationResult?
    @State private var episodeTranslation: TranslationResult?
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        Group {
            if isCompact {
                compactContent
            } else {
                regularContent
            }
        }
        .padding(isCompact ? 12 : 16)
        .frame(maxWidth: .infinity, minHeight: isCompact ? nil : 138, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isHovered ? Color.orange.opacity(0.36) : Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(isHovered ? 0.10 : 0.04), radius: isHovered ? 14 : 8, y: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? 1.012 : 1)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .task {
            await loadTranslations()
        }
    }

    private var regularContent: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncPosterImage(urlString: show.show.images?.poster?.first)
                .frame(width: 72, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(showTranslation?.title ?? show.show.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(episodeLine)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 3)
                }

                if let overview = show.episode?.overview ?? show.show.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 10) {
                Text(episodeCode)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Label(firstAiredTimeText, systemImage: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let network = show.show.network, !network.isEmpty {
                    Label(network, systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("查看详情")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
            }
            .frame(width: 150, alignment: .trailing)
        }
    }

    private var compactContent: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncPosterImage(urlString: show.show.images?.poster?.first)
                .frame(width: 56, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(showTranslation?.title ?? show.show.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(episodeLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(episodeCode, systemImage: "play.rectangle.fill")
                    Label(firstAiredTimeText, systemImage: "clock")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
    }

    private var episodeLine: String {
        guard let episode = show.episode else { return "剧集详情" }
        let title = episodeTranslation?.title ?? episode.title
        if let title, !title.isEmpty {
            return "S\(episode.season)E\(episode.number) · \(title)"
        }
        return "S\(episode.season)E\(episode.number)"
    }

    private var episodeCode: String {
        guard let episode = show.episode else { return "剧集" }
        return "S\(episode.season)E\(episode.number)"
    }

    private var firstAiredTimeText: String {
        guard let firstAired = show.firstAired,
              let date = CalendarViewModel.parseTraktDate(firstAired) else {
            return L10n.string("时间待定")
        }
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func loadTranslations() async {
        async let showTr = TranslationService.shared.getShowTranslation(id: show.show.ids.trakt)
        if let episode = show.episode {
            async let epTr = TranslationService.shared.getEpisodeTranslation(
                showId: show.show.ids.trakt,
                seasonNumber: episode.season,
                episodeNumber: episode.number
            )
            showTranslation = await showTr
            episodeTranslation = await epTr
        } else {
            showTranslation = await showTr
        }
    }
}

private struct CalendarLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在加载剧集日历...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}
