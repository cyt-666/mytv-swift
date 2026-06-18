import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var authService = AuthService.shared
    @State private var viewModel = SettingsViewModel()
    @State private var notificationService = MoviePilotNotificationService.shared
    @State private var showLogoutConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("设置")
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 72)

                // Account section
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
                .padding(.horizontal, 20)

                moviePilotSection

                // About section
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于")
                        .font(.headline)

                    HStack {
                        Text("MyTV for macOS")
                        Spacer()
                        Text(AppConstants.displayVersion)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 20)
            }
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

    private var moviePilotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MoviePilot")
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

                TextField("MoviePilot 地址", text: $viewModel.moviePilotHost)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $viewModel.moviePilotAPIKey)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Button {
                        Task { await viewModel.testMoviePilotConnection() }
                    } label: {
                        Label(viewModel.isTestingMoviePilot ? "测试中..." : "测试连接", systemImage: "network")
                    }
                    .disabled(viewModel.isTestingMoviePilot || viewModel.isSavingMoviePilot)

                    Button {
                        Task { await viewModel.saveMoviePilotSettings() }
                    } label: {
                        Label(viewModel.isSavingMoviePilot ? "保存中..." : "保存", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isTestingMoviePilot || viewModel.isSavingMoviePilot)

                    Button(role: .destructive) {
                        viewModel.clearMoviePilotSettings()
                    } label: {
                        Label("清除", systemImage: "trash")
                    }

                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MoviePilot 通知")
                                .font(.system(size: 14, weight: .semibold))
                            Text("通知权限：\(notificationService.authorizationStatusText)")
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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 20)
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
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
