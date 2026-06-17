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
        .disabled(viewModel.isSubscribing)
        .help(viewModel.isConfigured ? "添加 MoviePilot 订阅" : "配置 MoviePilot")
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
        return target.kind == .tv ? "选季订阅" : "订阅 MP"
    }

    private var buttonIcon: String {
        if viewModel.isSubscribing { return "hourglass" }
        if !viewModel.isConfigured { return "gearshape" }
        return "arrow.down.circle.fill"
    }

    private var buttonTint: Color {
        viewModel.isConfigured ? .indigo : .orange
    }

    private func handleTap() {
        guard viewModel.isConfigured else {
            onConfigure()
            return
        }
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
                statusRow(title: "订阅", value: viewModel.subscriptionLabel, icon: "rss", tint: viewModel.status.hasSubscription ? .indigo : .secondary)
                statusRow(title: "下载", value: viewModel.downloadLabel, icon: "arrow.down.circle.fill", tint: viewModel.status.downloads.isEmpty ? .secondary : .blue)
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
