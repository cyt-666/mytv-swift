import SwiftUI

enum DetailWatchedDateFormatter {
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let iso8601WithFractionalSeconds = makeISO8601Formatter(withFractionalSeconds: true)
        let iso8601 = makeISO8601Formatter(withFractionalSeconds: false)
        if let date = iso8601WithFractionalSeconds.date(from: value) ?? iso8601.date(from: value) {
            return date
        }
        return makeDateOnlyFormatter().date(from: value)
    }

    static func display(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func makeISO8601Formatter(withFractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = withFractionalSeconds ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }

    private static func makeDateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

enum WatchedDateChoice: String, CaseIterable, Identifiable {
    case now
    case releaseDate
    case custom

    var id: String { rawValue }

    func title(releaseDateLabel: String) -> String {
        switch self {
        case .now: return L10n.string("当前时间")
        case .releaseDate: return releaseDateLabel
        case .custom: return L10n.string("自定义")
        }
    }

    var icon: String {
        switch self {
        case .now: return "clock.fill"
        case .releaseDate: return "calendar.badge.clock"
        case .custom: return "calendar"
        }
    }
}

struct DetailMarkWatchedButton: View {
    let title: String
    let releaseDate: Date?
    let releaseDateLabel: String
    let isSubmitting: Bool
    let isCheckingStatus: Bool
    let isWatched: Bool
    let watchedAt: Date?
    let message: String?
    let errorMessage: String?
    let onMark: (Date) async -> Bool

    @State private var isShowingSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            Button {
                isShowingSheet = true
            } label: {
                Label(buttonTitle, systemImage: buttonIcon)
                    .font(.system(size: isCompact ? 13 : 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, isCompact ? 13 : 16)
                    .padding(.vertical, isCompact ? 8 : 9)
                    .background(Capsule().fill(Color.green.gradient))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.26), radius: isCompact ? 7 : 10, y: isCompact ? 3 : 5)
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: true)
            .disabled(isSubmitting || isCheckingStatus)
            .help(isWatched ? L10n.string("此条目已看，可继续添加观看记录") : L10n.string("标记这个条目为已看"))
            .sheet(isPresented: $isShowingSheet) {
                WatchedDatePickerSheet(
                    title: title,
                    releaseDate: releaseDate,
                    releaseDateLabel: releaseDateLabel,
                    onMark: onMark
                )
                .adaptiveDetailSheetFrame()
            }

            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                    .lineLimit(isCompact ? 2 : 3)
                    .frame(maxWidth: isCompact ? 220 : nil, alignment: .leading)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(isCompact ? 2 : 3)
                    .frame(maxWidth: isCompact ? 220 : nil, alignment: .leading)
            }
        }
    }

    private var buttonTitle: String {
        if isSubmitting {
            return L10n.string("标记中...")
        }
        if isCheckingStatus {
            return L10n.string("检查中...")
        }
        guard isWatched else { return L10n.string("标记已看") }
        guard let watchedAt else { return L10n.string("已看") }
        return L10n.string("已看 · %@", DetailWatchedDateFormatter.display(watchedAt))
    }

    private var buttonIcon: String {
        if isSubmitting || isCheckingStatus {
            return "hourglass"
        }
        return isWatched ? "checkmark.circle.fill" : "checkmark.circle.fill"
    }
}

struct DetailHeroActionGroup<Content: View>: View {
    private let content: Content
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if isCompact {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    content
                }
                .padding(.vertical, 2)
                .padding(.trailing, 18)
            }
            .scrollClipDisabled()
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 10) {
                content
            }
        }
    }
}

private struct WatchedDatePickerSheet: View {
    let title: String
    let releaseDate: Date?
    let releaseDateLabel: String
    let onMark: (Date) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selection: WatchedDateChoice = .now
    @State private var customDate = Date()
    @State private var isSubmitting = false

    private var choices: [WatchedDateChoice] {
        WatchedDateChoice.allCases.filter { choice in
            choice != .releaseDate || releaseDate != nil
        }
    }

    private var selectedDate: Date? {
        switch selection {
        case .now:
            return Date()
        case .releaseDate:
            return releaseDate
        case .custom:
            return customDate
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择观看日期")
                        .font(.system(size: 22, weight: .bold))
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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

            VStack(spacing: 8) {
                ForEach(choices) { choice in
                    choiceRow(choice)
                }
            }

            if selection == .custom {
                DatePicker(
                    "观看日期",
                    selection: $customDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }

            Button {
                Task { await submit() }
            } label: {
                Label(isSubmitting ? L10n.string("标记中...") : L10n.string("完成"), systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || selectedDate == nil)
        }
        .padding(22)
    }

    private func choiceRow(_ choice: WatchedDateChoice) -> some View {
        Button {
            selection = choice
        } label: {
            HStack(spacing: 12) {
                Image(systemName: choice.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(selection == choice ? Color.green : Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background((selection == choice ? Color.green : Color.accentColor).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title(releaseDateLabel: releaseDateLabel))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let subtitle = subtitle(for: choice) {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: selection == choice ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selection == choice ? Color.green : Color.secondary)
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for choice: WatchedDateChoice) -> String? {
        switch choice {
        case .now:
            return DetailWatchedDateFormatter.display(Date())
        case .releaseDate:
            return releaseDate.map(DetailWatchedDateFormatter.display)
        case .custom:
            return DetailWatchedDateFormatter.display(customDate)
        }
    }

    private func submit() async {
        guard let selectedDate, !isSubmitting else { return }
        isSubmitting = true
        let succeeded = await onMark(selectedDate)
        isSubmitting = false
        if succeeded {
            dismiss()
        }
    }
}

struct DetailMetaChip: View {
    let text: String
    var icon: String?
    var tint: Color = .secondary
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        HStack(spacing: isCompact ? 4 : 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
            }
            Text(text)
                .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, isCompact ? 8 : 10)
        .padding(.vertical, isCompact ? 5 : 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct MediaListActionMenu: View {
    let target: MediaListTarget?
    let viewModel: MediaListActionViewModel
    var prominent = true
    var iconOnly = false
    var onWatchlistAdded: (() -> Void)?
    @State private var isShowingSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            Button {
                isShowingSheet = true
            } label: {
                if iconOnly {
                    Image(systemName: viewModel.actionIcon)
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                        .foregroundStyle(viewModel.hasJoinedList ? .green : .primary)
                        .frame(width: isCompact ? 28 : 30, height: isCompact ? 27 : 28)
                } else {
                    Label(viewModel.actionTitle, systemImage: viewModel.actionIcon)
                        .font(.system(size: isCompact ? 13 : 14, weight: .bold))
                        .foregroundStyle(prominent ? .white : .primary)
                        .lineLimit(1)
                        .padding(.horizontal, prominent ? (isCompact ? 13 : 16) : (isCompact ? 11 : 13))
                        .padding(.vertical, prominent ? (isCompact ? 8 : 9) : (isCompact ? 7 : 7))
                        .background(actionBackground)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke((prominent ? Color.white : Color.primary).opacity(0.20), lineWidth: 1)
                        }
                        .shadow(color: prominent ? .black.opacity(0.26) : .clear, radius: isCompact ? 7 : 10, y: isCompact ? 3 : 5)
                }
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: true)
            .disabled(target == nil || viewModel.isSubmitting)
            .help(viewModel.hasJoinedList ? "管理观看清单和自定义列表" : "加入观看清单或自定义列表")
            .sheet(isPresented: $isShowingSheet) {
                MediaListActionSheet(
                    target: target,
                    viewModel: viewModel,
                    onWatchlistAdded: onWatchlistAdded
                )
                .adaptiveDetailSheetFrame()
            }
            .task(id: target) {
                await viewModel.loadStateIfNeeded(for: target)
            }

            if !iconOnly {
                if let message = viewModel.message {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                        .lineLimit(isCompact ? 2 : 3)
                        .frame(maxWidth: isCompact ? 220 : nil, alignment: .leading)
                }

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                        .lineLimit(isCompact ? 2 : 3)
                        .frame(maxWidth: isCompact ? 220 : nil, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var actionBackground: some View {
        if prominent {
            Capsule()
                .fill((viewModel.hasJoinedList ? Color.green : Color.accentColor).gradient)
        } else {
            Capsule()
                .fill(.thinMaterial)
        }
    }
}

private struct MediaListActionSheet: View {
    let target: MediaListTarget?
    let viewModel: MediaListActionViewModel
    let onWatchlistAdded: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var newListName = ""
    @State private var newListDescription = ""
    @State private var privacy = "private"
    @State private var displayNumbers = false
    @State private var allowComments = true
    @State private var shouldNotifyWatchlistAdded = false

    private let privacyOptions = [
        ("private", "私密"),
        ("friends", "好友可见"),
        ("public", "公开")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.hasJoinedList ? "管理列表" : "加入列表")
                        .font(.system(size: 22, weight: .bold))
                    Text(viewModel.hasJoinedList ? "当前条目已加入至少一个列表，可继续加入其他列表。" : "选择观看清单、自定义列表，或新建一个列表。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

            if let target {
                if viewModel.isLoggedIn {
                    actionButton(
                        title: viewModel.isInWatchlist ? "观看清单" : target.watchlistLabel,
                        icon: viewModel.isInWatchlist ? "bookmark.fill" : "bookmark",
                        isAdded: viewModel.isInWatchlist,
                        addedLabel: viewModel.isInWatchlist ? "移除" : nil,
                        isDestructiveAction: viewModel.isInWatchlist
                    ) {
                        if viewModel.isInWatchlist {
                            await viewModel.removeFromWatchlist(target)
                        } else {
                            let wasAdded = await viewModel.addToWatchlist(target)
                            if wasAdded, onWatchlistAdded != nil {
                                shouldNotifyWatchlistAdded = true
                                dismiss()
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("自定义列表")

                        if viewModel.isLoadingLists {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在加载列表...")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else if viewModel.lists.isEmpty {
                            Text("暂无自定义列表，可以在下面新建一个。")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.lists) { list in
                                    let isAdded = viewModel.isAdded(to: list)
                                    actionButton(
                                        title: list.name,
                                        subtitle: list.description,
                                        icon: isAdded ? "checkmark.circle.fill" : "list.bullet",
                                        isAdded: isAdded,
                                        addedLabel: isAdded ? "移除" : nil,
                                        isDestructiveAction: isAdded
                                    ) {
                                        await viewModel.toggle(target, in: list)
                                    }
                                }
                            }
                            .frame(maxHeight: 190)
                        }
                    }

                    Divider()

                    newListForm(target: target)
                } else {
                    Label("登录 Trakt 后才能加入观看清单或自定义列表", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            } else {
                Label("条目信息还在加载", systemImage: "hourglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let message = viewModel.message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            }
            .padding(22)
        }
        .task(id: target) {
            await viewModel.loadStateIfNeeded(for: target)
        }
        .onDisappear {
            if shouldNotifyWatchlistAdded {
                shouldNotifyWatchlistAdded = false
                onWatchlistAdded?()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.secondary)
    }

    private func actionButton(
        title: String,
        subtitle: String? = nil,
        icon: String,
        isAdded: Bool = false,
        addedLabel: String? = nil,
        isDestructiveAction: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isAdded ? .green : Color.accentColor)
                    .frame(width: 26, height: 26)
                    .background((isAdded ? Color.green : Color.accentColor).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isAdded {
                    Text(addedLabel ?? "已加入")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isDestructiveAction ? .orange : .green)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isAdded ? Color.green.opacity(0.08) : Color.clear)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isAdded ? Color.green.opacity(0.24) : Color.primary.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting)
    }

    private func newListForm(target: MediaListTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("新建列表并加入")

            TextField("列表名称", text: $newListName)
                .textFieldStyle(.roundedBorder)

            TextField("描述（可选）", text: $newListDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...3)

            Picker("可见性", selection: $privacy) {
                ForEach(privacyOptions, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 16) {
                Toggle("显示编号", isOn: $displayNumbers)
                Toggle("允许评论", isOn: $allowComments)
            }
            .font(.system(size: 13, weight: .medium))

            Button {
                Task {
                    let didCreate = await viewModel.createListAndAdd(
                        target,
                        name: newListName,
                        description: newListDescription,
                        privacy: privacy,
                        displayNumbers: displayNumbers,
                        allowComments: allowComments
                    )
                    if didCreate {
                        newListName = ""
                        newListDescription = ""
                        privacy = "private"
                        displayNumbers = false
                        allowComments = true
                    }
                }
            } label: {
                Label(viewModel.isSubmitting ? "创建中..." : "创建并加入", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSubmitting || newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct DetailHeroArtworkView: View {
    let urlString: String?
    let height: CGFloat
    var dimming: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AsyncPosterImage(urlString: urlString)
                    .frame(width: proxy.size.width, height: height)
                    .saturation(0.92)
                    .brightness(-0.05)
                    .clipped()

                Color.black.opacity(dimming)

                LinearGradient(
                    colors: [
                        .black.opacity(0.34),
                        .black.opacity(0.10),
                        .black.opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [
                        .black.opacity(0.86),
                        .black.opacity(0.32),
                        .black.opacity(0.08),
                        .black.opacity(0.20)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            .clear,
                            platformWindowBackgroundColor.opacity(0.34)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 74)
                }
            }
            .frame(width: proxy.size.width, height: height)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}

struct DetailSectionCard<Content: View>: View {
    let title: String
    private let content: Content
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            Text(title)
                .font(.system(size: isCompact ? 16 : 18, weight: .bold))

            content
        }
        .padding(isCompact ? 14 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

struct DetailInfoRow: View {
    let title: String
    let value: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 3) {
                titleText
                valueText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                titleText
                    .frame(width: 70, alignment: .leading)

                valueText
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var valueText: some View {
        Text(value)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(isCompact ? 3 : 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailStatTile: View {
    let title: String
    let value: String
    var icon: String?
    var tint: Color = .accentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.system(size: isCompact ? 18 : 24, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(title)
                .font(.system(size: isCompact ? 11 : 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(isCompact ? 12 : 16)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 78 : 108, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

struct DetailStatGrid<Content: View>: View {
    private let content: Content
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if isCompact {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                content
            }
        } else {
            VStack(spacing: 12) {
                content
            }
        }
    }
}

struct DetailGenreCloud: View {
    let genres: [String]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        FlowLayout(spacing: isCompact ? 6 : 8) {
            ForEach(genres, id: \.self) { genre in
                Text(genre)
                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                    .padding(.horizontal, isCompact ? 8 : 10)
                    .padding(.vertical, isCompact ? 5 : 6)
                    .background(.quaternary.opacity(0.65))
                    .clipShape(Capsule())
            }
        }
    }
}

struct DetailCommentsSection: View {
    let store: CommentInteractionStore
    let isLoggedIn: Bool
    let onSubmit: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        DetailSectionCard(title: "评论") {
            VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                HStack {
                    Text("来自 Trakt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        Task { await store.loadComments() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.rotate, isActive: store.isLoadingComments)
                    }
                    .buttonStyle(.borderless)
                    .disabled(store.isLoadingComments)
                    .help("刷新评论")
                }

                commentComposer

                if let errorMessage = store.commentErrorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }

                Divider().opacity(0.45)

                if store.isLoadingComments && store.comments.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if store.comments.isEmpty {
                    ContentUnavailableView(
                        "暂无评论",
                        systemImage: "bubble.left",
                        description: Text("这里会显示 Trakt 用户的公开评论")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.comments) { comment in
                            DetailCommentThreadView(
                                comment: comment,
                                store: store,
                                isLoggedIn: isLoggedIn
                            )
                        }

                        if store.canLoadMoreComments || store.isLoadingComments {
                            Button {
                                Task { await store.loadMoreComments() }
                            } label: {
                                if store.isLoadingComments {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("加载更多")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(store.isLoadingComments || !store.canLoadMoreComments)
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: Binding(
                get: { store.commentDraft },
                set: { store.commentDraft = $0 }
            ))
                .font(.system(size: 13))
                .frame(minHeight: isCompact ? 72 : 86)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if store.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(isLoggedIn ? "写一条 Trakt 评论..." : "登录 Trakt 后可以发布评论")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                        .allowsHitTesting(false)
                    }
                }
                .disabled(!isLoggedIn || store.isPostingComment)

            if isCompact {
                Toggle("包含剧透", isOn: Binding(
                    get: { store.commentHasSpoiler },
                    set: { store.commentHasSpoiler = $0 }
                ))
                    .platformCheckboxToggleStyle()
                    .disabled(!isLoggedIn || store.isPostingComment)

                Text("Trakt 通常要求评论至少 5 个词，200 词以上会作为 review。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                submitButton
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 12) {
                    Toggle("包含剧透", isOn: Binding(
                        get: { store.commentHasSpoiler },
                        set: { store.commentHasSpoiler = $0 }
                    ))
                        .platformCheckboxToggleStyle()
                        .disabled(!isLoggedIn || store.isPostingComment)

                    Text("Trakt 通常要求评论至少 5 个词，200 词以上会作为 review。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Spacer()

                    submitButton
                }
            }
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        if isCompact {
            submitButtonBase
                .buttonStyle(.borderedProminent)
        } else {
            submitButtonBase
                .buttonStyle(.bordered)
        }
    }

    private var submitButtonBase: some View {
        Button {
            onSubmit()
        } label: {
            if store.isPostingComment {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("发布")
            }
        }
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        isLoggedIn && !store.isPostingComment && !store.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct DetailCommentThreadView: View {
    let comment: CommentDTO
    let store: CommentInteractionStore
    let isLoggedIn: Bool

    @State private var showsReplies = false
    @State private var showsReplyComposer = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            DetailCommentRow(
                comment: comment,
                likeCount: store.displayLikeCount(for: comment),
                replyCount: store.displayReplyCount(for: comment)
            )

            commentActions

            if showsReplyComposer {
                replyComposer
            }

            if showsReplies {
                repliesView
            }
        }
        .padding(isCompact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var commentActions: some View {
        FlowLayout(spacing: isCompact ? 8 : 10) {
            likeButton

            if store.displayReplyCount(for: comment) > 0 {
                repliesButton
            }

            replyButton
        }
        .font(.system(size: 12, weight: .semibold))
        .buttonStyle(.borderless)
        .controlSize(.small)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
    }

    private var likeButton: some View {
        Button {
            Task { await store.toggleLike(for: comment) }
        } label: {
            Label(
                store.isLiked(comment) ? "已赞" : "赞",
                systemImage: store.isLiked(comment) ? "hand.thumbsup.fill" : "hand.thumbsup"
            )
        }
        .disabled(!isLoggedIn || store.isLiking(comment))
    }

    private var repliesButton: some View {
        Button {
            showsReplies.toggle()
            if showsReplies && store.repliesByCommentId[comment.id] == nil {
                Task { await store.loadReplies(for: comment) }
            }
        } label: {
            Label(showsReplies ? "隐藏回复" : "查看回复", systemImage: "bubble.left.and.bubble.right")
        }
    }

    private var replyButton: some View {
        Button {
            showsReplyComposer.toggle()
        } label: {
            Label("回复", systemImage: "arrowshape.turn.up.left")
        }
        .disabled(!isLoggedIn)
    }

    private var replyComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: Binding(
                get: { store.replyDrafts[comment.id] ?? "" },
                set: { store.replyDrafts[comment.id] = $0 }
            ))
            .font(.system(size: 13))
            .frame(minHeight: 64)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topLeading) {
                if (store.replyDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("回复 \(comment.displayName)...")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Toggle("包含剧透", isOn: Binding(
                    get: { store.replySpoilers.contains(comment.id) },
                    set: { value in
                        if value {
                            store.replySpoilers.insert(comment.id)
                        } else {
                            store.replySpoilers.remove(comment.id)
                        }
                    }
                ))
                .platformCheckboxToggleStyle()

                Spacer()

                Button("取消") {
                    showsReplyComposer = false
                }
                .buttonStyle(.borderless)

                Button {
                    Task {
                        let posted = await store.postReply(to: comment)
                        if posted {
                            showsReplyComposer = false
                            showsReplies = true
                        }
                    }
                } label: {
                    if store.isPostingReply(to: comment) {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("回复")
                    }
                }
                .disabled(replyText.isEmpty || store.isPostingReply(to: comment))
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(12)
        .background(.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var repliesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isLoadingReplies(for: comment) && (store.repliesByCommentId[comment.id] ?? []).isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                ForEach(store.repliesByCommentId[comment.id] ?? []) { reply in
                    DetailCommentRow(
                        comment: reply,
                        likeCount: store.displayLikeCount(for: reply),
                        replyCount: store.displayReplyCount(for: reply)
                    )
                    .padding(.leading, 14)
                }

                if store.canLoadMoreReplies(for: comment) {
                    Button {
                        Task { await store.loadMoreReplies(for: comment) }
                    } label: {
                        if store.isLoadingReplies(for: comment) {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("加载更多回复")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isLoadingReplies(for: comment))
                    .padding(.leading, 14)
                }
            }
        }
    }

    private var replyText: String {
        (store.replyDrafts[comment.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct DetailCommentRow: View {
    let comment: CommentDTO
    let likeCount: Int
    let replyCount: Int
    @State private var revealsSpoiler = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            commentHeader

            if comment.spoiler == true && !revealsSpoiler {
                HStack(spacing: 10) {
                    Label("这条评论包含剧透", systemImage: "eye.slash.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Button("显示") {
                        revealsSpoiler = true
                    }
                    .controlSize(.small)
                }
            } else {
                Text(comment.comment ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var commentHeader: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 5) {
                authorAndDate
                commentBadges
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                authorAndDate
                Spacer()
                commentBadges
            }
        }
    }

    private var authorAndDate: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(comment.displayName)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)

            if let date = comment.displayDate {
                Text(date)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var commentBadges: some View {
        HStack(spacing: 8) {
            if comment.review == true {
                Label("Review", systemImage: "text.bubble.fill")
            }
            if likeCount > 0 {
                Label("\(likeCount)", systemImage: "hand.thumbsup.fill")
            }
            if replyCount > 0 {
                Label("\(replyCount)", systemImage: "arrowshape.turn.up.left.fill")
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
    }
}

private var platformWindowBackgroundColor: Color {
    #if os(macOS)
    Color(nsColor: .windowBackgroundColor)
    #else
    Color(uiColor: .systemBackground)
    #endif
}

extension View {
    @ViewBuilder
    func platformCheckboxToggleStyle() -> some View {
        #if os(macOS)
        toggleStyle(.checkbox)
        #else
        toggleStyle(.switch)
        #endif
    }

    @ViewBuilder
    func adaptiveDetailSheetFrame() -> some View {
        #if os(iOS)
        self
            .frame(maxWidth: 520)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        self.frame(width: 460)
        #endif
    }
}
