import SwiftUI

struct SettingsView: View {
    @State private var authService = AuthService.shared
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

                // About section
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于")
                        .font(.headline)

                    HStack {
                        Text("MyTV for macOS")
                        Spacer()
                        Text("1.0.0")
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
    }
}
