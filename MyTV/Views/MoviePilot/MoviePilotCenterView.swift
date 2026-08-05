import SwiftUI

struct MoviePilotCenterView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MoviePilotCenterViewModel()
    @State private var selectedTab = MoviePilotCenterTab.downloads
    @State private var selectedSubscriptionKind = MoviePilotSubscriptionKind.movie
    @State private var subscriptionToDelete: MoviePilotSubscription?
    @State private var downloadToDelete: MoviePilotDownloadTask?
    @State private var workflowToRun: MoviePilotWorkflow?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !viewModel.isConfigured {
                    ContentUnavailableView {
                        Label("未配置媒体助手", systemImage: "link.badge.plus")
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
            .padding(.horizontal, isCompact ? 16 : 20)
            .padding(.top, isCompact ? 18 : 72)
            .padding(.bottom, 28)
        }
        .task {
            await viewModel.loadAll()
        }
        .task(id: selectedTab) {
            await refreshDownloadsWhileVisible()
        }
        .refreshable {
            await viewModel.refresh(tab: selectedTab)
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
            Button("删除下载任务", role: .destructive) {
                if let download = downloadToDelete {
                    Task { await viewModel.deleteDownload(download) }
                }
                downloadToDelete = nil
            }
            Button("取消", role: .cancel) {
                downloadToDelete = nil
            }
        } message: {
            Text(downloadToDelete?.displayTitle ?? "确认删除这个下载任务？")
        }
        .confirmationDialog("运行工作流", isPresented: workflowRunDialog, titleVisibility: .visible) {
            Button("从头开始") {
                runPendingWorkflow(fromBeginning: true)
            }
            Button("从上次位置继续") {
                runPendingWorkflow(fromBeginning: false)
            }
            Button("取消", role: .cancel) {
                workflowToRun = nil
            }
        } message: {
            if let workflowToRun {
                Text("\(workflowToRun.displayName)\n工作流 ID：\(workflowToRun.id)")
            }
        }
    }

    private var header: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 14) {
                    titleBlock
                    tabControl
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    titleBlock
                    Spacer()
                    tabControl
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MoviePilot")
                .font(.system(size: isCompact ? 30 : 34, weight: .bold))
            Text(viewModel.supportsWorkflows ? "订阅、下载任务、消息和工作流" : "订阅、下载任务和消息")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var tabControl: some View {
        NativeSegmentedControl(
            selection: $selectedTab,
            items: viewModel.availableTabs,
            title: { $0.segmentTitle }
        )
        .frame(maxWidth: isCompact ? .infinity : nil)
        .frame(width: isCompact ? nil : (viewModel.supportsWorkflows ? 400 : 300))
        .frame(height: 44)
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
        case .workflows:
            workflowsContent
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("下载任务")
                    .font(.system(size: 16, weight: .bold))

                if viewModel.hasLoadedDownloads {
                    Text("\(viewModel.downloads.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.55))
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    Task { await viewModel.loadDownloads() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: viewModel.isLoadingDownloads)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoadingDownloads || viewModel.isPerformingAction)
                .help("刷新下载任务")
            }

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

    private func refreshDownloadsWhileVisible() async {
        guard selectedTab == .downloads else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            guard selectedTab == .downloads, viewModel.isConfigured else { continue }
            await viewModel.loadDownloads()
        }
    }

    private var subscriptionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            NativeSegmentedControl(
                selection: $selectedSubscriptionKind,
                items: MoviePilotSubscriptionKind.allCases,
                title: { "\($0.segmentTitle) \(subscriptionCount(for: $0))" }
            )
            .frame(maxWidth: isCompact ? .infinity : 240)
            .frame(height: 44)

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

    private var workflowsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("按名称筛选", text: $viewModel.workflowNameFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .onSubmit {
                        Task { await viewModel.loadWorkflows() }
                    }

                Picker("状态", selection: $viewModel.workflowStateFilter) {
                    ForEach(MoviePilotWorkflowStateFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .labelsHidden()
                .frame(width: 130)

                Picker("触发方式", selection: $viewModel.workflowTriggerFilter) {
                    ForEach(MoviePilotWorkflowTriggerFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .labelsHidden()
                .frame(width: 150)

                Button("应用筛选") {
                    Task { await viewModel.loadWorkflows() }
                }
                .disabled(viewModel.isLoadingWorkflows || viewModel.isPerformingAction)

                Spacer()
            }

            if (viewModel.isLoadingWorkflows || viewModel.errorMessage == nil) &&
                !viewModel.hasLoadedWorkflows &&
                viewModel.workflows.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if viewModel.workflows.isEmpty {
                ContentUnavailableView(
                    "未找到工作流",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("可以调整筛选条件后重新查询。")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.workflows) { workflow in
                        MoviePilotWorkflowRow(
                            workflow: workflow,
                            isPerformingAction: viewModel.isPerformingAction,
                            onRun: {
                                workflowToRun = workflow
                            }
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

    private var workflowRunDialog: Binding<Bool> {
        Binding(
            get: { workflowToRun != nil },
            set: { isPresented in
                if !isPresented { workflowToRun = nil }
            }
        )
    }

    private func runPendingWorkflow(fromBeginning: Bool) {
        guard let workflow = workflowToRun else { return }
        workflowToRun = nil
        Task {
            await viewModel.runWorkflow(workflow, fromBeginning: fromBeginning)
        }
    }
}

private struct MoviePilotWorkflowRow: View {
    let workflow: MoviePilotWorkflow
    let isPerformingAction: Bool
    let onRun: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.indigo)
                .frame(width: 38, height: 38)
                .background(.indigo.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(workflow.displayName)
                        .font(.system(size: 15, weight: .semibold))

                    Text("ID \(workflow.id)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    workflowStateBadge
                }

                if let description = nonEmpty(workflow.description) {
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Label(workflow.displayTriggerType, systemImage: "bolt.fill")
                    Label("运行 \(workflow.runCount ?? 0) 次", systemImage: "number")

                    if let lastTime = nonEmpty(workflow.lastTime) {
                        Label(lastTime, systemImage: "clock")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

                if let currentAction = nonEmpty(workflow.currentAction) {
                    Label("当前动作：\(currentAction)", systemImage: "arrow.right.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .textSelection(.enabled)

            Button("运行") {
                onRun()
            }
            .buttonStyle(.borderedProminent)
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

    private var workflowStateBadge: some View {
        Text(workflow.displayState)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(stateTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stateTint.opacity(0.13))
            .clipShape(Capsule())
    }

    private var stateTint: Color {
        switch workflow.displayState {
        case "运行中": return .blue
        case "成功": return .green
        case "失败": return .red
        case "暂停": return .orange
        default: return .secondary
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

private struct MoviePilotDownloadTaskRow: View {
    let download: MoviePilotDownloadTask
    let isPerformingAction: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        Group {
            if isCompact {
                compactBody
            } else {
                regularBody
            }
        }
        .padding(isCompact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var regularBody: some View {
        HStack(alignment: .top, spacing: 14) {
            statusIcon(size: 34, iconSize: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(download.displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

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

            Spacer(minLength: 0)

            actionButtons
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                statusIcon(size: 30, iconSize: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(download.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(download.stateLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(download.isPaused ? Color.orange : Color.blue)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                actionButtons
            }

            downloadInfoFlow

            if let progressValue {
                ProgressView(value: progressValue)
                    .tint(download.isPaused ? .orange : .blue)
            }
        }
    }

    private func statusIcon(size: CGFloat, iconSize: CGFloat) -> some View {
        Image(systemName: download.isPaused ? "pause.circle.fill" : "arrow.down.circle.fill")
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(download.isPaused ? Color.orange : Color.blue)
            .frame(width: size, height: size)
            .background((download.isPaused ? Color.orange : Color.blue).opacity(0.12))
            .clipShape(Circle())
    }

    private var downloadInfoFlow: some View {
        FlowLayout(spacing: 6) {
            if !download.displaySubtitle.isEmpty {
                downloadInfoChip(download.displaySubtitle)
            }
            if let progress = download.progress, !progress.isEmpty {
                downloadInfoChip(progress)
            }
            if let leftTime = download.leftTime, !leftTime.isEmpty {
                downloadInfoChip(leftTime)
            }
        }
    }

    private func downloadInfoChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.42))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: isCompact ? 4 : 6) {
            if download.canModify {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: download.isPaused ? "play.fill" : "pause.fill")
                        .frame(width: isCompact ? 28 : nil, height: isCompact ? 28 : nil)
                }
                .help(download.isPaused ? "恢复下载" : "暂停下载")
            }

            if download.canDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: isCompact ? 28 : nil, height: isCompact ? 28 : nil)
                }
                .help("删除下载任务")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(isPerformingAction)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            HStack(spacing: 8) {
                Spacer(minLength: 0)

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
        MoviePilotMessageTextFormatter.cleaned(message.title) ?? L10n.string("媒体助手消息")
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
