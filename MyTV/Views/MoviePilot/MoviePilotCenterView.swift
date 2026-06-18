import SwiftUI

struct MoviePilotCenterView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MoviePilotCenterViewModel()
    @State private var selectedTab = MoviePilotCenterTab.downloads
    @State private var selectedSubscriptionKind = MoviePilotSubscriptionKind.movie
    @State private var subscriptionToDelete: MoviePilotSubscription?
    @State private var downloadToDelete: MoviePilotDownloadTask?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !viewModel.isConfigured {
                    ContentUnavailableView {
                        Label("未配置 MoviePilot", systemImage: "link.badge.plus")
                    } actions: {
                        Button("打开设置") {
                            appState.navigate(to: .settings)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    statusMessages
                    selectedContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 72)
            .padding(.bottom, 28)
        }
        .task {
            await viewModel.loadAll()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refresh(tab: selectedTab) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoading)
                }
                .disabled(viewModel.isLoading || viewModel.isPerformingAction || !viewModel.isConfigured)
                .help("刷新")
            }
        }
        .confirmationDialog("删除订阅", isPresented: subscriptionDeleteDialog, titleVisibility: .visible) {
            Button("删除订阅", role: .destructive) {
                if let subscription = subscriptionToDelete {
                    Task { await viewModel.deleteSubscription(subscription) }
                }
                subscriptionToDelete = nil
            }
            Button("取消", role: .cancel) {
                subscriptionToDelete = nil
            }
        } message: {
            Text(subscriptionToDelete?.displayTitle ?? "确认删除这个 MoviePilot 订阅？")
        }
        .confirmationDialog("删除下载任务", isPresented: downloadDeleteDialog, titleVisibility: .visible) {
            Button("删除任务", role: .destructive) {
                if let download = downloadToDelete {
                    Task { await viewModel.deleteDownload(download, deleteFiles: false) }
                }
                downloadToDelete = nil
            }
            Button("删除任务并删除文件", role: .destructive) {
                if let download = downloadToDelete {
                    Task { await viewModel.deleteDownload(download, deleteFiles: true) }
                }
                downloadToDelete = nil
            }
            Button("取消", role: .cancel) {
                downloadToDelete = nil
            }
        } message: {
            Text("默认只从下载器删除任务，不删除已下载文件。")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MoviePilot")
                    .font(.system(size: 34, weight: .bold))
                Text("订阅、下载任务和消息")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            NativeSegmentedControl(
                selection: $selectedTab,
                items: MoviePilotCenterTab.allCases,
                title: { $0.segmentTitle }
            )
            .frame(width: 300, height: 44)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .downloads:
            downloadsContent
        case .subscriptions:
            subscriptionsContent
        case .messages:
            messagesContent
        }
    }

    private var statusMessages: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = viewModel.actionMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                    .lineLimit(3)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
        }
    }

    private var downloadsContent: some View {
        VStack(spacing: 10) {
            if (viewModel.isLoadingDownloads || viewModel.errorMessage == nil) &&
                !viewModel.hasLoadedDownloads &&
                viewModel.downloads.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if viewModel.downloads.isEmpty {
                ContentUnavailableView("暂无下载任务", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.downloads) { download in
                        MoviePilotDownloadTaskRow(
                            download: download,
                            isPerformingAction: viewModel.isPerformingAction,
                            onToggle: {
                                Task { await viewModel.setDownload(download, paused: !download.isPaused) }
                            },
                            onDelete: {
                                downloadToDelete = download
                            }
                        )
                    }
                }
            }
        }
    }

    private var subscriptionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            NativeSegmentedControl(
                selection: $selectedSubscriptionKind,
                items: MoviePilotSubscriptionKind.allCases,
                title: { "\($0.segmentTitle) \(subscriptionCount(for: $0))" }
            )
            .frame(width: 240, height: 44)

            if (viewModel.isLoadingSubscriptions || viewModel.errorMessage == nil) &&
                !viewModel.hasLoadedSubscriptions &&
                viewModel.visibleSubscriptions(for: selectedSubscriptionKind).isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if viewModel.visibleSubscriptions(for: selectedSubscriptionKind).isEmpty {
                ContentUnavailableView(selectedSubscriptionKind.emptyTitle, systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.visibleSubscriptions(for: selectedSubscriptionKind)) { subscription in
                        MoviePilotSubscriptionRow(
                            subscription: subscription,
                            posterURL: viewModel.subscriptionPosterURL(for: subscription),
                            detailRoute: viewModel.subscriptionRoute(for: subscription),
                            isPerformingAction: viewModel.isPerformingAction,
                            onOpen: { route in
                                appState.navigate(to: route)
                            },
                            onToggle: {
                                Task { await viewModel.setSubscription(subscription, paused: !subscription.isPaused) }
                            },
                            onDelete: {
                                subscriptionToDelete = subscription
                            }
                        )
                    }
                }
            }
        }
    }

    private func subscriptionCount(for kind: MoviePilotSubscriptionKind) -> Int {
        viewModel.visibleSubscriptions(for: kind).count
    }

    private var messagesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isResolvingMessagePosters && !viewModel.messages.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在补全海报")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if (viewModel.isLoadingMessages || viewModel.errorMessage == nil) &&
                !viewModel.hasLoadedMessages &&
                viewModel.messages.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if viewModel.messages.isEmpty {
                ContentUnavailableView("暂无消息", systemImage: "bell")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MoviePilotMessageRow(
                            message: message,
                            posterURL: viewModel.messagePosterURL(for: message)
                        )
                    }
                }
            }
        }
    }

    private var subscriptionDeleteDialog: Binding<Bool> {
        Binding(
            get: { subscriptionToDelete != nil },
            set: { isPresented in
                if !isPresented { subscriptionToDelete = nil }
            }
        )
    }

    private var downloadDeleteDialog: Binding<Bool> {
        Binding(
            get: { downloadToDelete != nil },
            set: { isPresented in
                if !isPresented { downloadToDelete = nil }
            }
        )
    }
}

private struct MoviePilotDownloadTaskRow: View {
    let download: MoviePilotDownloadTask
    let isPerformingAction: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: download.isPaused ? "pause.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(download.isPaused ? Color.orange : Color.blue)
                .frame(width: 34, height: 34)
                .background((download.isPaused ? Color.orange : Color.blue).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(download.displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(download.displaySubtitle)
                    Text(download.stateLabel)
                    if let progress = download.progress, !progress.isEmpty {
                        Text(progress)
                    }
                    if let leftTime = download.leftTime, !leftTime.isEmpty {
                        Text(leftTime)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let progressValue {
                    ProgressView(value: progressValue)
                        .tint(download.isPaused ? .orange : .blue)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if download.canModify {
                    Button {
                        onToggle()
                    } label: {
                        Image(systemName: download.isPaused ? "play.fill" : "pause.fill")
                    }
                    .help(download.isPaused ? "恢复下载" : "暂停下载")
                }

                if download.canDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("删除下载任务")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(isPerformingAction)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var progressValue: Double? {
        guard let progress = download.progress?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: ""),
              let value = Double(progress) else {
            return nil
        }
        return max(0, min(value / 100, 1))
    }
}

private struct MoviePilotSubscriptionRow: View {
    let subscription: MoviePilotSubscription
    let posterURL: String?
    let detailRoute: Route?
    let isPerformingAction: Bool
    let onOpen: (Route) -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            if let detailRoute {
                Button {
                    onOpen(detailRoute)
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .help("打开详情")
                .onHover { isHovered = $0 }
            } else {
                rowContent
                    .help("未匹配到 Trakt 详情")
            }

            HStack(spacing: 6) {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: subscription.isPaused ? "play.fill" : "pause.fill")
                }
                .help(subscription.isPaused ? "恢复订阅" : "暂停订阅")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .help("删除订阅")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(isPerformingAction)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)

            if isHovered && detailRoute != nil {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AsyncPosterImage(urlString: posterURL)
                    .frame(width: 48, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.primary.opacity(0.08), lineWidth: 1)
                    }

                Image(systemName: subscription.isPaused ? "pause.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(subscription.isPaused ? Color.orange : Color.indigo)
                    .padding(4)
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .offset(x: 5, y: 5)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(subscription.displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(subscription.displaySubtitle)
                    Text(subscription.stateLabel)
                    if let totalEpisode = subscription.totalEpisode {
                        Text("共 \(totalEpisode)")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct MoviePilotMessageRow: View {
    let message: MoviePilotMessage
    let posterURL: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            poster

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    categoryBadge
                }

                if let text = displayText {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let regTime = nonEmpty(message.regTime) {
                    Text(regTime)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .textSelection(.enabled)

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var poster: some View {
        ZStack(alignment: .bottomTrailing) {
            if let posterURL {
                AsyncPosterImage(urlString: posterURL)
                    .frame(width: 64, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(.primary.opacity(0.08), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconTint.opacity(0.12))
                    .frame(width: 64, height: 96)
                    .overlay {
                        Image(systemName: category?.systemImage ?? "bell.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(iconTint)
                    }
            }

            Image(systemName: category?.systemImage ?? "bell.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(iconTint)
                .padding(5)
                .background(.regularMaterial)
                .clipShape(Circle())
                .offset(x: 5, y: 5)
        }
        .frame(width: 64, height: 96)
    }

    private var categoryBadge: some View {
        Text(message.mtype ?? "其它")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(iconTint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(iconTint.opacity(0.12))
            .clipShape(Capsule())
            .fixedSize()
    }

    private var displayTitle: String {
        MoviePilotMessageTextFormatter.cleaned(message.title) ?? "MoviePilot 消息"
    }

    private var displayText: String? {
        MoviePilotMessageTextFormatter.cleaned(message.text)
    }

    private var category: MoviePilotNotificationCategory? {
        MoviePilotNotificationCategory.category(for: message)
    }

    private var iconTint: Color {
        switch category {
        case .organize: return .green
        case .download: return .blue
        case .subscribe: return .indigo
        case .exception: return .orange
        case .none: return .secondary
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
