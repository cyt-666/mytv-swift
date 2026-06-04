import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !authService.isLoggedIn {
                    LoginWebView()
                } else if let user = viewModel.user {
                    ProfileHeaderView(user: user)

                    if let stats = viewModel.stats {
                        LifetimeStatsSection(stats: stats)
                    } else {
                        ProfileSectionPlaceholder(title: "累计统计")
                    }

                    MonthStatsSection(
                        currentMonthStats: viewModel.currentMonthStats,
                        previousMonthStats: viewModel.previousMonthStats
                    )

                    ActivitySection(
                        activities: viewModel.activities,
                        isLoading: viewModel.isLoadingActivities,
                        errorMessage: viewModel.activityErrorMessage,
                        onSelect: { route in appState.navigate(to: route) }
                    )
                } else if viewModel.isLoading {
                    ProgressView("正在加载个人资料...")
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    ContentUnavailableView(
                        viewModel.errorMessage ?? "个人资料加载失败",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("请稍后重试。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
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

    private var authService: AuthService { .shared }
}

private struct ProfileHeaderView: View {
    let user: UserDTO
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            ProfileAvatarView(user: user, size: 96)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(displayName)
                        .font(.system(size: 34, weight: .bold))
                        .lineLimit(1)

                    if user.isVIP {
                        Label("VIP", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.yellow)
                            .labelStyle(.titleAndIcon)
                    }
                }

                Text("@\(user.username)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                if let description = user.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
                    if let location = user.location, !location.isEmpty {
                        ProfileMetaLabel(icon: "mappin.and.ellipse", text: location)
                    }
                    if let website = user.website, !website.isEmpty {
                        ProfileMetaLabel(icon: "link", text: website)
                    }
                    if let joinedAt = formattedJoinedDate {
                        ProfileMetaLabel(icon: "calendar", text: "加入于 \(joinedAt)")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [.white.opacity(0.08), .orange.opacity(0.08), .clear]
                        : [.white.opacity(0.55), .orange.opacity(0.07), .blue.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.10 : 0.08), lineWidth: 1)
        }
    }

    private var displayName: String {
        if let name = user.name, !name.isEmpty {
            return name
        }
        return user.username
    }

    private var formattedJoinedDate: String? {
        guard let joinedAt = user.joinedAt,
              let date = MonthlyWatchStatsService.parseTraktDate(joinedAt) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
}

private struct ProfileAvatarView: View {
    let user: UserDTO
    let size: CGFloat
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(.quaternary)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.28), lineWidth: 1)
        }
        .task(id: user.images?.avatar?.full) {
            await loadAvatar()
        }
    }

    private var initials: String {
        let source = user.name?.isEmpty == false ? user.name! : user.username
        return String(source.prefix(1)).uppercased()
    }

    private func loadAvatar() async {
        guard let urlString = user.images?.avatar?.full, !urlString.isEmpty else {
            image = nil
            return
        }
        let fullURL = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
        guard let url = URL(string: fullURL) else {
            image = nil
            return
        }
        image = await ImageService.shared.load(url: url)
    }
}

private struct ProfileMetaLabel: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .lineLimit(1)
    }
}

private struct LifetimeStatsSection: View {
    let stats: UserStatsDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "累计统计", icon: "chart.bar.fill")
            CumulativeStatsPanel(stats: stats)
        }
    }
}

private struct CumulativeStatsPanel: View {
    let stats: UserStatsDTO
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                FeaturedLifetimeMetric(
                    icon: "clock.fill",
                    title: "观看时长",
                    value: hoursText(totalMinutes),
                    subtitle: "电影与剧集累计估算"
                )
                .frame(width: 250, alignment: .leading)

                Divider()
                    .padding(.vertical, 6)

                VStack(spacing: 0) {
                    LifetimeMetricRow(metrics: primaryMetrics)
                    Divider().opacity(0.55)
                    LifetimeMetricRow(metrics: secondaryMetrics)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 0) {
                FeaturedLifetimeMetric(
                    icon: "clock.fill",
                    title: "观看时长",
                    value: hoursText(totalMinutes),
                    subtitle: "电影与剧集累计估算"
                )
                Divider().opacity(0.55)
                LifetimeMetricRow(metrics: Array(primaryMetrics.prefix(2)))
                Divider().opacity(0.55)
                LifetimeMetricRow(metrics: [primaryMetrics[2], secondaryMetrics[0]])
                Divider().opacity(0.55)
                LifetimeMetricRow(metrics: Array(secondaryMetrics.suffix(2)))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 214, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.10 : 0.07), lineWidth: 1)
        }
    }

    private var totalMinutes: Int {
        stats.movies.minutes + stats.episodes.minutes
    }

    private var commentTotal: Int {
        stats.movies.comments + stats.shows.comments + stats.seasons.comments + stats.episodes.comments
    }

    private var primaryMetrics: [LifetimeMetric] {
        [
            LifetimeMetric(icon: "film.fill", title: "电影", value: "\(stats.movies.watched)", subtitle: "\(stats.movies.plays) 次播放"),
            LifetimeMetric(icon: "tv.fill", title: "剧集", value: "\(stats.episodes.watched)", subtitle: "\(stats.shows.watched) 部剧"),
            LifetimeMetric(icon: "folder.fill", title: "收藏", value: "\(stats.movies.collected + stats.shows.collected)", subtitle: "电影 + 剧集")
        ]
    }

    private var secondaryMetrics: [LifetimeMetric] {
        [
            LifetimeMetric(icon: "star.fill", title: "评分", value: "\(stats.ratings.total)", subtitle: "所有评分"),
            LifetimeMetric(icon: "text.bubble.fill", title: "评论", value: "\(commentTotal)", subtitle: "评论与影评"),
            LifetimeMetric(icon: "person.2.fill", title: "关注", value: "\(stats.network.following)", subtitle: "\(stats.network.followers) 位关注者")
        ]
    }

    private func hoursText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "暂无" }
        let hours = Double(minutes) / 60
        if hours < 100 {
            return String(format: "%.1f 小时", hours)
        }
        return "\(minutes / 60) 小时"
    }
}

private struct LifetimeMetric: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let subtitle: String
}

private struct FeaturedLifetimeMetric: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(.system(size: 36, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.trailing, 22)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
    }
}

private struct LifetimeMetricRow: View {
    let metrics: [LifetimeMetric]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                LifetimeInlineMetric(metric: metric)

                if index < metrics.count - 1 {
                    Divider()
                        .frame(height: 66)
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

private struct LifetimeInlineMetric: View {
    let metric: LifetimeMetric

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: metric.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.value)
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(metric.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(metric.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
    }
}

private struct MonthStatsSection: View {
    let currentMonthStats: MonthlyWatchStats?
    let previousMonthStats: MonthlyWatchStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "月度统计", icon: "calendar")

            HStack(alignment: .top, spacing: 12) {
                MonthStatPanel(label: "本月", stats: currentMonthStats)
                MonthStatPanel(label: "上月", stats: previousMonthStats)
            }
        }
    }
}

private struct MonthStatPanel: View {
    let label: String
    let stats: MonthlyWatchStats?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(stats?.monthTitle ?? "加载中")
                        .font(.system(size: 20, weight: .bold))
                }
                Spacer()
            }

            if let stats {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(stats.totalCount)")
                        .font(.system(size: 38, weight: .bold))
                    Text("次观看")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 20) {
                    MiniMetric(title: "电影", value: "\(stats.movieCount)")
                    MiniMetric(title: "剧集", value: "\(stats.episodeCount)")
                    MiniMetric(title: "天数", value: "\(stats.watchedDays)")
                    MiniMetric(title: "时长", value: stats.estimatedHoursText)
                }

                Divider().opacity(0.55)

                Label(
                    stats.busiestDay.map { "\($0) 最活跃 · \(stats.busiestDayCount) 次" } ?? "暂无活跃日期",
                    systemImage: "flame.fill"
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(stats.busiestDay == nil ? Color.secondary : Color.orange)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 130)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 238, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.10 : 0.07), lineWidth: 1)
        }
    }
}

private struct MiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActivitySection: View {
    let activities: [ProfileActivityItem]
    let isLoading: Bool
    let errorMessage: String?
    let onSelect: (Route) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "个人动态", icon: "sparkles")

            if isLoading && activities.isEmpty {
                ProfileSectionPlaceholder(title: "正在加载评论和评分")
            } else if let errorMessage, activities.isEmpty {
                ContentUnavailableView(
                    errorMessage,
                    systemImage: "exclamationmark.triangle",
                    description: Text("稍后刷新个人资料页再试。")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else if activities.isEmpty {
                ContentUnavailableView(
                    "暂无评论和评分",
                    systemImage: "text.bubble",
                    description: Text("你发表的评论、影评和评分会显示在这里。")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(activities) { item in
                        if let route = item.route {
                            Button {
                                onSelect(route)
                            } label: {
                                ProfileActivityRow(item: item)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ProfileActivityRow(item: item)
                        }
                    }
                }
            }
        }
    }
}

private struct ProfileActivityRow: View {
    let item: ProfileActivityItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            AsyncPosterImage(urlString: item.posterURL)
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Label(item.kind.title, systemImage: item.kind.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.kind == .rating ? .yellow : .orange)

                    Text(item.dateText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)

                    Spacer(minLength: 0)
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let body = item.body {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let rating = item.rating {
                RatingPill(rating: rating)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.10 : 0.07), lineWidth: 1)
        }
    }
}

private struct RatingPill: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
            Text("\(rating)")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.yellow.opacity(0.13))
        .clipShape(Capsule())
    }
}

private struct SectionTitle: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)
            Text(title)
                .font(.system(size: 20, weight: .bold))
            Spacer()
        }
    }
}

private struct ProfileSectionPlaceholder: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.75)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
