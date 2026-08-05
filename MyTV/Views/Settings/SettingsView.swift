import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var authService = AuthService.shared
    @State private var viewModel = SettingsViewModel()
    @State private var notificationService = MoviePilotNotificationService.shared
    @State private var showLogoutConfirm = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        AdaptiveLayout.isCompact(horizontalSizeClass)
    }

    private var sectionHorizontalPadding: CGFloat {
        isCompact ? 16 : 20
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("设置")
                    .font(.system(size: isCompact ? 30 : 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, sectionHorizontalPadding)
                    .padding(.top, isCompact ? 18 : 72)

                // Account section
                languageSection

                VStack(alignment: .leading, spacing: 12) {
                    Text("账号")
                        .font(.headline)

                    if authService.isLoggedIn {
                        HStack {
                            Text("已登录 Trakt 账号")
                            Spacer()
                            Button("退出登录") {
                                showLogoutConfirm = true
                            }
                            .foregroundColor(.red)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Button("登录 Trakt 账号") {
                            Task { try? await authService.login() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, sectionHorizontalPadding)

                moviePilotSection

                // About section
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于")
                        .font(.headline)

                    HStack {
                        Text(AppConstants.platformDisplayName)
                        Spacer()
                        Text(AppConstants.displayVersion)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, sectionHorizontalPadding)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .alert("确认退出登录", isPresented: $showLogoutConfirm) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task { try? await authService.logout() }
            }
        } message: {
            Text("退出后将无法同步观看记录")
        }
        .task {
            viewModel.loadMoviePilotSettings()
            await viewModel.loadSubscriptionOptions()
            await notificationService.refreshAuthorizationStatus()
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("语言")
                .font(.headline)

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(.blue.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("界面语言")
                        .font(.system(size: 14, weight: .semibold))

                    Text("修改后会立即应用到 MyTV 的界面文案。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Picker("界面语言", selection: Binding(
                    get: { appState.appLanguage },
                    set: { appState.setAppLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.localizedNameKey)
                            .tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .padding(isCompact ? 14 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, sectionHorizontalPadding)
    }

    private var moviePilotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("媒体助手")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: moviePilotStatusIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(moviePilotStatusTint)
                        .frame(width: 32, height: 32)
                        .background(moviePilotStatusTint.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.moviePilotConnectionSummary)
                            .font(.system(size: 14, weight: .semibold))
                        Text("用于订阅、下载状态、入库状态和入库通知")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                TextField("媒体助手地址", text: $viewModel.moviePilotHost)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $viewModel.moviePilotAPIKey)
                    .textFieldStyle(.roundedBorder)

                connectionButtons

                Divider()

                subscriptionPreferencesSection

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("媒体助手通知")
                                .font(.system(size: 14, weight: .semibold))
                            Text(L10n.string("通知权限：%@", notificationService.authorizationStatusText))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { viewModel.moviePilotNotificationsEnabled },
                            set: { enabled in
                                Task { await viewModel.setMoviePilotNotificationsEnabled(enabled) }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    VStack(spacing: 8) {
                        ForEach(MoviePilotNotificationCategory.allCases) { category in
                            HStack(spacing: 12) {
                                Image(systemName: category.systemImage)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(category.settingsDescription)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Toggle("", isOn: Binding(
                                    get: { viewModel.moviePilotNotificationCategories.contains(category) },
                                    set: { enabled in
                                        viewModel.setMoviePilotNotificationCategory(category, enabled: enabled)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .accessibilityLabel(category.displayName)
                            }
                            .frame(maxWidth: .infinity)
                            .disabled(!viewModel.moviePilotNotificationsEnabled)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if notificationService.authorizationStatus == .denied {
                    HStack(spacing: 10) {
                        Label("需要在系统设置中允许 MyTV 发送通知", systemImage: "bell.badge")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)

                        Spacer()

                        Button("打开系统设置") {
                            openNotificationSettings()
                        }
                    }
                }

                if let message = viewModel.moviePilotMessage {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }

                if let error = viewModel.moviePilotErrorMessage ?? notificationService.lastErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, sectionHorizontalPadding)
    }

    private var connectionButtons: some View {
        Group {
            if isCompact {
                VStack(spacing: 10) {
                    moviePilotTestButton
                    moviePilotSaveButton
                    moviePilotClearButton
                }
            } else {
                HStack(spacing: 10) {
                    moviePilotTestButton
                    moviePilotSaveButton
                    moviePilotClearButton
                    Spacer()
                }
            }
        }
    }

    private var moviePilotTestButton: some View {
        Button {
            Task { await viewModel.testMoviePilotConnection() }
        } label: {
            Label(viewModel.isTestingMoviePilot ? L10n.string("测试中...") : L10n.string("测试连接"), systemImage: "network")
                .frame(maxWidth: isCompact ? .infinity : nil)
        }
        .disabled(viewModel.isTestingMoviePilot || viewModel.isSavingMoviePilot)
    }

    private var moviePilotSaveButton: some View {
        Button {
            Task {
                await viewModel.saveMoviePilotSettings()
                appState.refreshMediaAssistantConfiguration()
            }
        } label: {
            Label(viewModel.isSavingMoviePilot ? L10n.string("保存中...") : L10n.string("保存"), systemImage: "checkmark.circle")
                .frame(maxWidth: isCompact ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isTestingMoviePilot || viewModel.isSavingMoviePilot)
    }

    private var moviePilotClearButton: some View {
        Button(role: .destructive) {
            viewModel.clearMoviePilotSettings()
            appState.refreshMediaAssistantConfiguration()
        } label: {
            Label("清除", systemImage: "trash")
                .frame(maxWidth: isCompact ? .infinity : nil)
        }
    }

    private var subscriptionPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("订阅偏好")
                        .font(.system(size: 14, weight: .semibold))
                    Text("作为每次订阅的默认值，确认时仍可临时修改")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker(
                    "默认预设",
                    selection: $viewModel.moviePilotSubscriptionPreferences.preset
                ) {
                    ForEach(MoviePilotSubscriptionPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            Text(viewModel.moviePilotSubscriptionPreferences.preset.description)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if viewModel.moviePilotSubscriptionPreferences.preset == .custom {
                VStack(spacing: 9) {
                    TextField(
                        "质量正则，例如 BluRay|WEB-DL",
                        text: $viewModel.moviePilotSubscriptionPreferences.customQuality
                    )
                    TextField(
                        "分辨率正则，例如 1080p|2160p",
                        text: $viewModel.moviePilotSubscriptionPreferences.customResolution
                    )
                    TextField(
                        "特效正则，例如 HDR|DV|SDR",
                        text: $viewModel.moviePilotSubscriptionPreferences.customEffect
                    )

                    HStack(spacing: 10) {
                        SubscriptionSiteMenu(
                            sites: viewModel.moviePilotSites,
                            selection: $viewModel.moviePilotSubscriptionPreferences.siteIDs
                        )
                        SubscriptionRuleGroupMenu(
                            groups: viewModel.moviePilotRuleGroups,
                            selection: $viewModel.moviePilotSubscriptionPreferences.filterGroupNames
                        )
                        if viewModel.isLoadingSubscriptionOptions {
                            ProgressView().controlSize(.small)
                        }
                        Spacer()
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                Spacer()
                Button {
                    viewModel.saveMoviePilotSubscriptionPreferences()
                } label: {
                    Label("保存订阅偏好", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var moviePilotStatusIcon: String {
        if !viewModel.isMoviePilotConfigured { return "link.badge.plus" }
        if viewModel.availableMoviePilotTools.isEmpty { return "link" }
        return "checkmark.circle.fill"
    }

    private var moviePilotStatusTint: Color {
        if !viewModel.isMoviePilotConfigured { return .secondary }
        if viewModel.availableMoviePilotTools.isEmpty { return .orange }
        return .green
    }

    private func openNotificationSettings() {
        #if os(macOS)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
        #endif
    }
}

private struct SubscriptionSiteMenu: View {
    let sites: [MoviePilotConfiguredSite]
    @Binding var selection: Set<Int>

    var body: some View {
        Menu {
            if sites.isEmpty {
                Text("MoviePilot 未提供可选站点")
            } else {
                ForEach(sites) { site in
                    Button {
                        if selection.contains(site.id) {
                            selection.remove(site.id)
                        } else {
                            selection.insert(site.id)
                        }
                    } label: {
                        Label(
                            site.name,
                            systemImage: selection.contains(site.id) ? "checkmark" : ""
                        )
                    }
                }
            }
        } label: {
            Label(
                selection.isEmpty ? "全部站点" : "已选 \(selection.count) 个站点",
                systemImage: "globe"
            )
        }
    }
}

private struct SubscriptionRuleGroupMenu: View {
    let groups: [MoviePilotRuleGroup]
    @Binding var selection: Set<String>

    var body: some View {
        Menu {
            if groups.isEmpty {
                Text("MoviePilot 未提供规则组")
            } else {
                ForEach(groups) { group in
                    Button {
                        if selection.contains(group.name) {
                            selection.remove(group.name)
                        } else {
                            selection.insert(group.name)
                        }
                    } label: {
                        Label(
                            group.name,
                            systemImage: selection.contains(group.name) ? "checkmark" : ""
                        )
                    }
                }
            }
        } label: {
            Label(
                selection.isEmpty ? "不指定规则组" : "已选 \(selection.count) 个规则组",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
    }
}
