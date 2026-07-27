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
                            Toggle(isOn: Binding(
                                get: { viewModel.moviePilotNotificationCategories.contains(category) },
                                set: { enabled in
                                    viewModel.setMoviePilotNotificationCategory(category, enabled: enabled)
                                }
                            )) {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.displayName)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(category.settingsDescription)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: category.systemImage)
                                }
                            }
                            .toggleStyle(.switch)
                            .disabled(!viewModel.moviePilotNotificationsEnabled)
                        }
                    }
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
