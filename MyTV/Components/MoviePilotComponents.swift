import SwiftUI

struct MoviePilotSubscribeButton: View {
    let target: MoviePilotMediaTarget
    var seasons: [SeasonDTO] = []
    let viewModel: MoviePilotMediaViewModel
    let onConfigure: () -> Void

    @State private var isShowingSeasonPicker = false

    var body: some View {
        Button {
            handleTap()
        } label: {
            Label(buttonTitle, systemImage: buttonIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(buttonTint.gradient)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.26), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(viewModel.isSubscribing || isFullySubscribed)
        .help(buttonHelp)
        .sheet(isPresented: $isShowingSeasonPicker) {
            MoviePilotSeasonPickerSheet(
                target: target,
                seasons: seasons.filter { $0.number > 0 },
                viewModel: viewModel
            )
            .frame(width: 460)
        }
        .task(id: target) {
            await viewModel.loadStatusIfNeeded(for: target)
        }
    }

    private var buttonTitle: String {
        if viewModel.isSubscribing { return "提交中..." }
        if !viewModel.isConfigured { return "配置 MoviePilot" }
        if isFullySubscribed { return "已订阅" }
        if hasLibraryReminder {
            if target.kind == .tv {
                return viewModel.status.hasSubscription ? "已入库·继续" : "已入库·选季"
            }
            return "已入库·订阅"
        }
        if target.kind == .tv {
            return viewModel.status.hasSubscription ? "继续订阅" : "选季订阅"
        }
        return "订阅 MP"
    }

    private var buttonIcon: String {
        if viewModel.isSubscribing { return "hourglass" }
        if !viewModel.isConfigured { return "gearshape" }
        if isFullySubscribed { return "checkmark.circle.fill" }
        if hasLibraryReminder { return "externaldrive.fill" }
        return "arrow.down.circle.fill"
    }

    private var buttonTint: Color {
        if !viewModel.isConfigured { return .orange }
        return isFullySubscribed || hasLibraryReminder ? .green : .indigo
    }

    private var buttonHelp: String {
        if !viewModel.isConfigured { return "配置 MoviePilot" }
        if isFullySubscribed { return "已添加 MoviePilot 订阅" }
        if hasLibraryReminder {
            return target.kind == .tv ? "MoviePilot 已入库，可继续订阅缺失季度" : "MoviePilot 已入库，通常无需重复订阅"
        }
        return target.kind == .tv ? "添加 MoviePilot 季度订阅" : "添加 MoviePilot 订阅"
    }

    private var hasLibraryReminder: Bool {
        viewModel.status.hasLibraryItem && !isFullySubscribed
    }

    private var regularSeasons: [SeasonDTO] {
        seasons.filter { $0.number > 0 }
    }

    private var isFullySubscribed: Bool {
        guard viewModel.status.hasSubscription else { return false }
        guard target.kind == .tv else { return true }
        if viewModel.status.subscriptions.contains(where: { $0.season == nil }) {
            return true
        }
        guard !regularSeasons.isEmpty else { return true }
        return regularSeasons.allSatisfy { viewModel.isSeasonSubscribed($0.number) }
    }

    private func handleTap() {
        guard viewModel.isConfigured else {
            onConfigure()
            return
        }
        guard !isFullySubscribed else { return }
        if target.kind == .tv {
            isShowingSeasonPicker = true
        } else {
            Task { await viewModel.subscribe(target: target) }
        }
    }
}

struct MoviePilotStatusPanel: View {
    let target: MoviePilotMediaTarget
    let viewModel: MoviePilotMediaViewModel
    let onConfigure: () -> Void

    @State private var subscriptionToDelete: MoviePilotSubscription?
    @State private var downloadToDelete: MoviePilotDownloadTask?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MoviePilot", systemImage: "bolt.horizontal.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    if viewModel.isConfigured {
                        Task { await viewModel.loadStatus(for: target) }
                    } else {
                        onConfigure()
                    }
                } label: {
                    Image(systemName: viewModel.isConfigured ? "arrow.clockwise" : "gearshape")
                        .symbolEffect(.rotate, isActive: viewModel.isLoadingStatus)
                }
                .buttonStyle(.borderless)
                .help(viewModel.isConfigured ? "刷新 MoviePilot 状态" : "配置 MoviePilot")
            }

            if viewModel.isConfigured {
                statusRow(title: "入库", value: viewModel.libraryLabel, icon: "externaldrive.fill", tint: viewModel.status.hasLibraryItem ? .green : .secondary)
                statusRow(
                    title: "订阅",
                    value: viewModel.subscriptionLabel,
                    icon: viewModel.status.hasSubscription ? "checkmark.seal.fill" : "plus.circle.fill",
                    tint: viewModel.status.hasSubscription ? .indigo : .secondary
                )
                statusRow(title: "下载", value: viewModel.downloadLabel, icon: "arrow.down.circle.fill", tint: viewModel.status.downloads.isEmpty ? .secondary : .blue)

                if !viewModel.status.subscriptions.isEmpty || !viewModel.status.downloads.isEmpty {
                    Divider()
                    actionRows
                }
            } else {
                Button {
                    onConfigure()
                } label: {
                    Label("配置连接", systemImage: "link.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if let message = viewModel.message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                    .lineLimit(2)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
        .task(id: target) {
            await viewModel.loadStatusIfNeeded(for: target)
        }
        .confirmationDialog("删除订阅", isPresented: subscriptionDeleteDialog, titleVisibility: .visible) {
            Button("删除订阅", role: .destructive) {
                if let subscription = subscriptionToDelete {
                    Task { await viewModel.deleteSubscription(subscription, target: target) }
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
                    Task { await viewModel.deleteDownload(download, deleteFiles: false, target: target) }
                }
                downloadToDelete = nil
            }
            Button("删除任务并删除文件", role: .destructive) {
                if let download = downloadToDelete {
                    Task { await viewModel.deleteDownload(download, deleteFiles: true, target: target) }
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

    private var actionRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.status.subscriptions) { subscription in
                subscriptionActionRow(subscription)
            }

            ForEach(viewModel.status.downloads) { download in
                downloadActionRow(download)
            }
        }
    }

    private func statusRow(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
    }

    private func subscriptionActionRow(_ subscription: MoviePilotSubscription) -> some View {
        HStack(spacing: 8) {
            Image(systemName: subscription.isPaused ? "pause.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(subscription.isPaused ? Color.orange : Color.indigo)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(subscription.displayTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text("订阅 · \(subscription.stateLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                Task { await viewModel.setSubscription(subscription, paused: !subscription.isPaused, target: target) }
            } label: {
                Image(systemName: subscription.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(viewModel.isPerformingAction)
            .help(subscription.isPaused ? "恢复订阅" : "暂停订阅")

            Button(role: .destructive) {
                subscriptionToDelete = subscription
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(viewModel.isPerformingAction)
            .help("删除订阅")
        }
    }

    private func downloadActionRow(_ download: MoviePilotDownloadTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: download.isPaused ? "pause.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(download.isPaused ? Color.orange : Color.blue)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(download.displayTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text("下载 · \(download.stateLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if download.canModify {
                Button {
                    Task { await viewModel.setDownload(download, paused: !download.isPaused, target: target) }
                } label: {
                    Image(systemName: download.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(viewModel.isPerformingAction)
                .help(download.isPaused ? "恢复下载" : "暂停下载")
            }

            if download.canDelete {
                Button(role: .destructive) {
                    downloadToDelete = download
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(viewModel.isPerformingAction)
                .help("删除下载任务")
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

private struct MoviePilotSeasonPickerSheet: View {
    let target: MoviePilotMediaTarget
    let seasons: [SeasonDTO]
    let viewModel: MoviePilotMediaViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeasons: Set<Int>

    init(target: MoviePilotMediaTarget, seasons: [SeasonDTO], viewModel: MoviePilotMediaViewModel) {
        self.target = target
        self.seasons = seasons
        self.viewModel = viewModel
        _selectedSeasons = State(initialValue: Set(seasons.first.map { [$0.number] } ?? []))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择订阅季度")
                        .font(.system(size: 22, weight: .bold))
                    Text(target.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(.thinMaterial)
                .clipShape(Circle())
            }

            if seasons.isEmpty {
                Label("暂无可订阅季度", systemImage: "rectangle.stack.badge.minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(seasons) { season in
                            seasonRow(season)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("取消") {
                    dismiss()
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.subscribe(target: target, seasons: Array(selectedSeasons))
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    Label(viewModel.isSubscribing ? "提交中..." : "订阅所选", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSeasons.isEmpty || viewModel.isSubscribing)
            }
        }
        .padding(22)
        .onAppear {
            let defaultSeason = seasons.first { !viewModel.isSeasonSubscribed($0.number) }?.number ?? seasons.first?.number
            selectedSeasons = Set(defaultSeason.map { [$0] } ?? [])
        }
    }

    private func seasonRow(_ season: SeasonDTO) -> some View {
        let isSubscribed = viewModel.isSeasonSubscribed(season.number)
        return Button {
            if selectedSeasons.contains(season.number) {
                selectedSeasons.remove(season.number)
            } else {
                selectedSeasons.insert(season.number)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedSeasons.contains(season.number) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(selectedSeasons.contains(season.number) ? Color.indigo : Color.secondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(season.title ?? "第 \(season.number) 季")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let episodeCount = season.episodeCount {
                            Text("\(episodeCount) 集")
                        }
                        if isSubscribed {
                            Text("已订阅")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSubscribed ? Color.green.opacity(0.08) : Color.clear)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSubscribed ? Color.green.opacity(0.24) : Color.primary.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
