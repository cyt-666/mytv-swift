import SwiftUI

struct MoviePilotSubscribeButton: View {
    let target: MoviePilotMediaTarget
    var seasons: [SeasonDTO] = []
    let viewModel: MoviePilotMediaViewModel
    let onConfigure: () -> Void

    @State private var isShowingSubscriptionSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            Label(buttonTitle, systemImage: buttonIcon)
                .font(.system(size: isCompact ? 13 : 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, isCompact ? 13 : 16)
                .padding(.vertical, isCompact ? 8 : 9)
                .background(buttonTint.gradient)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.26), radius: isCompact ? 7 : 10, y: isCompact ? 3 : 5)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: true)
        .disabled(viewModel.isSubscribing || isFullySubscribed)
        .help(buttonHelp)
        .sheet(isPresented: $isShowingSubscriptionSheet) {
            MoviePilotSubscriptionSheet(
                target: target,
                seasons: seasons.filter { $0.number > 0 },
                viewModel: viewModel
            )
            .adaptiveDetailSheetFrame()
        }
        .task(id: target) {
            await viewModel.loadStatusIfNeeded(for: target)
        }
    }

    private var buttonTitle: String {
        if viewModel.isSubscribing { return L10n.string("提交中...") }
        if !viewModel.isConfigured { return L10n.string("配置 MoviePilot") }
        if isFullySubscribed { return L10n.string("已订阅") }
        if hasLibraryReminder {
            if target.kind == .tv {
                return viewModel.status.hasSubscription ? L10n.string("已入库·继续") : L10n.string("已入库·选季")
            }
            return L10n.string("已入库·订阅")
        }
        if target.kind == .tv {
            return viewModel.status.hasSubscription ? L10n.string("继续订阅") : L10n.string("选季订阅")
        }
        return L10n.string("订阅助手")
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
        if !viewModel.isConfigured { return L10n.string("配置 MoviePilot") }
        if isFullySubscribed { return L10n.string("已添加 MoviePilot 订阅") }
        if hasLibraryReminder {
            return target.kind == .tv ? L10n.string("MoviePilot 已入库，可继续订阅缺失季度") : L10n.string("MoviePilot 已入库，通常无需重复订阅")
        }
        return target.kind == .tv ? L10n.string("添加 MoviePilot 季度订阅") : L10n.string("添加 MoviePilot 订阅")
    }

    private var hasLibraryReminder: Bool {
        viewModel.status.hasLibraryItem && !isFullySubscribed
    }

    private var regularSeasons: [SeasonDTO] {
        seasons.filter { $0.number > 0 }
    }

    private var isFullySubscribed: Bool {
        viewModel.isFullySubscribed(target: target, seasons: regularSeasons)
    }

    private func handleTap() {
        guard viewModel.isConfigured else {
            onConfigure()
            return
        }
        guard !isFullySubscribed else { return }
        isShowingSubscriptionSheet = true
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
                Label("媒体助手", systemImage: "bolt.horizontal.circle.fill")
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
                .help(viewModel.isConfigured ? L10n.string("刷新 MoviePilot 状态") : L10n.string("配置 MoviePilot"))
            }

            if viewModel.isConfigured {
                statusRow(title: L10n.string("入库"), value: viewModel.libraryLabel, icon: "externaldrive.fill", tint: viewModel.status.hasLibraryItem ? .green : .secondary)
                statusRow(
                    title: L10n.string("订阅"),
                    value: viewModel.subscriptionLabel,
                    icon: viewModel.status.hasSubscription ? "checkmark.seal.fill" : "plus.circle.fill",
                    tint: viewModel.status.hasSubscription ? .indigo : .secondary
                )
                statusRow(title: L10n.string("下载"), value: viewModel.downloadLabel, icon: "arrow.down.circle.fill", tint: viewModel.status.downloads.isEmpty ? .secondary : .blue)

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
                    Task { await viewModel.deleteDownload(download, target: target) }
                }
                downloadToDelete = nil
            }
            Button("取消", role: .cancel) {
                downloadToDelete = nil
            }
        } message: {
            Text(downloadToDelete?.displayTitle ?? "确认删除这个下载任务？")
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
                Text(L10n.string("订阅 · %@", subscription.stateLabel))
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
            .help(subscription.isPaused ? L10n.string("恢复订阅") : L10n.string("暂停订阅"))

            Button(role: .destructive) {
                subscriptionToDelete = subscription
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(viewModel.isPerformingAction)
            .help(L10n.string("删除订阅"))
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
                Text(L10n.string("下载 · %@", download.stateLabel))
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
                .help(download.isPaused ? L10n.string("恢复下载") : L10n.string("暂停下载"))
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
                .help(L10n.string("删除下载任务"))
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

struct MoviePilotSubscriptionSheet: View {
    let target: MoviePilotMediaTarget
    let seasons: [SeasonDTO]
    let viewModel: MoviePilotMediaViewModel
    let introMessage: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeasons: Set<Int>
    @State private var preferences: MoviePilotSubscriptionPreferences
    @State private var availableSites: [MoviePilotConfiguredSite] = []
    @State private var availableRuleGroups: [MoviePilotRuleGroup] = []
    @State private var isLoadingOptions = false
    @State private var optionsErrorMessage: String?

    init(
        target: MoviePilotMediaTarget,
        seasons: [SeasonDTO] = [],
        viewModel: MoviePilotMediaViewModel,
        introMessage: String? = nil
    ) {
        self.target = target
        self.seasons = seasons.filter { $0.number > 0 }.sorted { $0.number < $1.number }
        self.viewModel = viewModel
        self.introMessage = introMessage
        let defaultSeason = self.seasons.first { !viewModel.isSeasonSubscribed($0.number) }?.number
        _selectedSeasons = State(initialValue: Set(defaultSeason.map { [$0] } ?? []))
        _preferences = State(initialValue: MoviePilotSettingsStore.subscriptionPreferences())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.kind == .tv ? "确认 MoviePilot 季度订阅" : "确认 MoviePilot 订阅")
                        .font(.system(size: 22, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
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

            if let introMessage {
                Label(introMessage, systemImage: "bookmark.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if target.kind == .tv {
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
                    .frame(maxHeight: 280)
                }
            }

            subscriptionOptions

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            if let optionsErrorMessage {
                Label(optionsErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("取消") {
                    dismiss()
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.subscribe(
                            target: target,
                            seasons: target.kind == .tv ? Array(selectedSeasons) : nil,
                            preferences: preferences
                        )
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    Label(
                        viewModel.isSubscribing
                            ? L10n.string("提交中...")
                            : L10n.string(target.kind == .tv ? "订阅所选" : "确认订阅"),
                        systemImage: "arrow.down.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    (target.kind == .tv && selectedSeasons.isEmpty) ||
                    viewModel.isSubscribing
                )
            }
        }
        .padding(22)
        .frame(minWidth: 360, idealWidth: 560, maxWidth: 560)
        .onAppear {
            let defaultSeason = seasons.first { !viewModel.isSeasonSubscribed($0.number) }?.number
            selectedSeasons = Set(defaultSeason.map { [$0] } ?? [])
        }
        .task(id: preferences.preset) {
            if preferences.preset == .custom {
                await loadOptions()
            }
        }
    }

    private var subscriptionOptions: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("本次订阅预设")
                        .font(.system(size: 14, weight: .semibold))
                    Text(preferences.preset.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("预设", selection: $preferences.preset) {
                    ForEach(MoviePilotSubscriptionPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            if preferences.preset == .custom {
                TextField("质量正则，例如 BluRay|WEB-DL", text: $preferences.customQuality)
                TextField("分辨率正则，例如 1080p|2160p", text: $preferences.customResolution)
                TextField("特效正则，例如 HDR|DV|SDR", text: $preferences.customEffect)

                HStack(spacing: 10) {
                    subscriptionSiteMenu
                    subscriptionRuleGroupMenu
                    if isLoadingOptions {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(13)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var subscriptionSiteMenu: some View {
        Menu {
            if availableSites.isEmpty {
                Text("未提供可选站点")
            } else {
                ForEach(availableSites) { site in
                    Button {
                        if preferences.siteIDs.contains(site.id) {
                            preferences.siteIDs.remove(site.id)
                        } else {
                            preferences.siteIDs.insert(site.id)
                        }
                    } label: {
                        Label(
                            site.name,
                            systemImage: preferences.siteIDs.contains(site.id) ? "checkmark" : ""
                        )
                    }
                }
            }
        } label: {
            Label(
                preferences.siteIDs.isEmpty ? "全部站点" : "站点 \(preferences.siteIDs.count)",
                systemImage: "globe"
            )
        }
    }

    private var subscriptionRuleGroupMenu: some View {
        Menu {
            if availableRuleGroups.isEmpty {
                Text("未提供规则组")
            } else {
                ForEach(availableRuleGroups) { group in
                    Button {
                        if preferences.filterGroupNames.contains(group.name) {
                            preferences.filterGroupNames.remove(group.name)
                        } else {
                            preferences.filterGroupNames.insert(group.name)
                        }
                    } label: {
                        Label(
                            group.name,
                            systemImage: preferences.filterGroupNames.contains(group.name)
                                ? "checkmark"
                                : ""
                        )
                    }
                }
            }
        } label: {
            Label(
                preferences.filterGroupNames.isEmpty
                    ? "不指定规则组"
                    : "规则组 \(preferences.filterGroupNames.count)",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
    }

    private func loadOptions() async {
        guard preferences.preset == .custom, !isLoadingOptions else { return }
        isLoadingOptions = true
        optionsErrorMessage = nil
        defer { isLoadingOptions = false }

        do {
            async let sites = MoviePilotAPIClient.shared.fetchConfiguredSites()
            async let ruleGroups = MoviePilotAPIClient.shared.fetchRuleGroups()
            availableSites = try await sites
            availableRuleGroups = try await ruleGroups
        } catch {
            optionsErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
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
                    Text(season.title ?? L10n.string("第 %d 季", season.number))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let episodeCount = season.episodeCount {
                            Text(L10n.string("%d 集", episodeCount))
                        }
                        if isSubscribed {
                            Text(L10n.string("已订阅"))
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
        .disabled(isSubscribed)
    }
}
