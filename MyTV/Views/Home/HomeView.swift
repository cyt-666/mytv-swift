import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(AppState.self) private var appState
    private let sidebarOverlapInset: CGFloat = 48
    private let contentHorizontalPadding: CGFloat = 24
    private let topContentPadding: CGFloat = 56
    private var safeLeadingInset: CGFloat { sidebarOverlapInset + contentHorizontalPadding }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    MonthlyStatsHeroView(
                        stats: viewModel.monthlyStats,
                        isLoading: viewModel.isLoading,
                        isLoggedIn: AuthService.shared.isLoggedIn
                    )
                    .padding(.top, topContentPadding)
                    .padding(.leading, contentHorizontalPadding)
                    .padding(.trailing, contentHorizontalPadding)

                    VStack(spacing: 32) {
                        // Continue watching
                        if !viewModel.upNextItems.isEmpty {
                            ContinueWatchingRail(
                                items: viewModel.upNextItems,
                                leadingInset: safeLeadingInset,
                                leadingBleed: sidebarOverlapInset,
                                trailingInset: contentHorizontalPadding
                            )
                        }

                        // Start watching (watchlist ∩ collection)
                        if !viewModel.startWatchingShows.isEmpty {
                            MediaRailView(
                                title: "开始观看",
                                items: viewModel.startWatchingShows.map { .show($0) },
                                icon: "play.fill",
                                iconColor: .green,
                                leadingInset: safeLeadingInset,
                                leadingBleed: sidebarOverlapInset,
                                trailingInset: contentHorizontalPadding
                            )
                        }

                        // Recommended movies
                        if !viewModel.recommendedMovies.isEmpty {
                            MediaRailView(
                                title: "推荐电影",
                                items: viewModel.recommendedMovies.map { .movie($0) },
                                icon: "hand.thumbsup.fill",
                                iconColor: GlassDesign.accentBlue,
                                onSeeAll: { appState.navigate(to: .recommendations(type: "movies")) },
                                leadingInset: safeLeadingInset,
                                leadingBleed: sidebarOverlapInset,
                                trailingInset: contentHorizontalPadding
                            )
                        }

                        // Recommended shows
                        if !viewModel.recommendedShows.isEmpty {
                            MediaRailView(
                                title: "推荐剧集",
                                items: viewModel.recommendedShows.map { .show($0) },
                                icon: "heart.fill",
                                iconColor: .red,
                                onSeeAll: { appState.navigate(to: .recommendations(type: "shows")) },
                                leadingInset: safeLeadingInset,
                                leadingBleed: sidebarOverlapInset,
                                trailingInset: contentHorizontalPadding
                            )
                        }
                    }
                    .padding(.top, 26)
                    .padding(.bottom, 36)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .background(DetailBackgroundClearer())
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

private struct MonthlyStatsHeroView: View {
    let stats: MonthlyWatchStats?
    let isLoading: Bool
    let isLoggedIn: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            if !isLoggedIn {
                loginPrompt
            } else if stats == nil {
                ProgressView("正在加载本月观影数据...")
                    .frame(maxWidth: .infinity, minHeight: 210)
            } else if let stats, stats.totalCount > 0 {
                statsContent(stats)
            } else {
                emptyState
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .background(MonthlyStatsHeroBackground(backgroundURL: stats?.backgroundURL))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.11 : 0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.07), radius: 26, y: 14)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(stats?.monthTitle ?? currentMonthTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("本月观影")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }

    private func statsContent(_ stats: MonthlyWatchStats) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 28) {
                MonthlyMetricView(title: "总观看", value: "\(stats.totalCount)", unit: "次")
                MonthlyMetricView(title: "电影", value: "\(stats.movieCount)", unit: "部")
                MonthlyMetricView(title: "剧集", value: "\(stats.episodeCount)", unit: "集")
                MonthlyMetricView(title: "观看天数", value: "\(stats.watchedDays)", unit: "天")
            }

            Divider().opacity(0.45)

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 10) {
                    MonthlyInsightRow(icon: "clock", title: "估算时长", value: stats.estimatedHoursText)
                    MonthlyInsightRow(
                        icon: "flame",
                        title: "最活跃",
                        value: stats.busiestDay.map { "\($0) · \(stats.busiestDayCount) 次" } ?? "暂无"
                    )
                }
                .frame(width: 220, alignment: .leading)

                if !stats.recentItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近观看")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(stats.recentItems) { item in
                            MonthlyRecentWatchRow(item: item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var loginPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("登录 Trakt 后查看你的本月观影统计。")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                Task { try? await AuthService.shared.login() }
            } label: {
                Label("登录 Trakt", systemImage: "person.crop.circle.badge.checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .center)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "popcorn")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text("这个月还没有观看记录")
                .font(.system(size: 18, weight: .semibold))

            Text("看过的电影和剧集会在这里汇总。")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 210)
    }

    private var currentMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: Date())
    }
}

private struct MonthlyStatsHeroBackground: View {
    let backgroundURL: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.thinMaterial)

            if let backgroundURL {
                AsyncPosterImage(urlString: backgroundURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .saturation(colorScheme == .dark ? 0.95 : 1.05)
                    .contrast(colorScheme == .dark ? 1.02 : 1.08)
                    .opacity(colorScheme == .dark ? 0.40 : 0.46)
                    .overlay {
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [
                                    .black.opacity(0.68),
                                    .black.opacity(0.36),
                                    .black.opacity(0.56)
                                ]
                                : [
                                    .white.opacity(0.70),
                                    .white.opacity(0.44),
                                    .white.opacity(0.64)
                                ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
            }

            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        .white.opacity(0.07),
                        .orange.opacity(0.08),
                        .blue.opacity(0.05),
                        .black.opacity(0.16)
                    ]
                    : [
                        .white.opacity(0.24),
                        .orange.opacity(0.05),
                        .blue.opacity(0.035),
                        .white.opacity(0.08)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    .clear,
                    .orange.opacity(colorScheme == .dark ? 0.18 : 0.14),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct MonthlyMetricView: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .bold))
                Text(unit)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MonthlyInsightRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

private struct MonthlyRecentWatchRow: View {
    let item: MonthlyRecentWatchItem

    var body: some View {
        HStack(spacing: 10) {
            AsyncPosterImage(urlString: item.posterURL)
                .frame(width: 34, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Continue Watching Rail

private struct ContinueWatchingRail: View {
    let items: [UpNextItemDTO]
    var leadingInset: CGFloat = 0
    var leadingBleed: CGFloat = 0
    var trailingInset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)

                Text("继续观看")
                    .font(.system(size: 20, weight: .bold))

                Spacer()
            }
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(items) { item in
                        ContinueWatchingCard(item: item)
                    }
                }
                .padding(.leading, leadingBleed + leadingInset)
                .padding(.trailing, trailingInset)
            }
            .padding(.leading, -leadingBleed)
            .scrollClipDisabled()
        }
    }
}

private struct ContinueWatchingCard: View {
    let item: UpNextItemDTO
    @State private var showTranslation: TranslationResult?
    @State private var isHovered = false
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.navigate(
                to: .episodeDetail(
                    showId: item.show.ids.trakt,
                    seasonNumber: item.nextEpisode.season,
                    episodeNumber: item.nextEpisode.number
                )
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Poster with episode overlay
                ZStack(alignment: .bottomLeading) {
                    AsyncPosterImage(urlString: item.show.images?.poster?.first)
                        .frame(width: 160, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Episode info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("S\(item.nextEpisode.season)E\(item.nextEpisode.number)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(item.nextEpisode.title ?? "")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(10)
                }
                .frame(width: 160, height: 240)

                // Show title
                Text(showTranslation?.title ?? item.show.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                    .frame(width: 160, alignment: .leading)

                // Progress bar
                ProgressView(value: Double(item.progress.completed), total: Double(max(item.progress.aired, 1)))
                    .tint(.blue)
                    .frame(width: 160)
            }
            .contentShape(Rectangle())
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .task {
            showTranslation = await TranslationService.shared.getShowTranslation(id: item.show.ids.trakt)
        }
    }
}
