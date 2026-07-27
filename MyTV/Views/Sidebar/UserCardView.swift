import SwiftUI

struct UserCardView: View {
    @Environment(AppState.self) private var appState
    @State private var authService = AuthService.shared
    @State private var avatarImage: PlatformImage?

    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            if let avatarImage {
                Image(platformImage: avatarImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(authService.userProfile?.user.name ?? authService.userProfile?.user.username ?? (authService.isLoggedIn ? "已登录" : "游客"))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(authService.isLoggedIn ? "@\(authService.userProfile?.user.username ?? "...")" : "点击登录")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.navigate(to: .settings)
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            if !authService.isLoggedIn {
                Task { try? await authService.login() }
            } else {
                appState.navigate(to: .profile)
            }
        }
        .task {
            await loadAvatar()
        }
        .onChange(of: authService.userProfile?.user.images?.avatar?.full) { _, _ in
            Task { await loadAvatar() }
        }
    }

    private func loadAvatar() async {
        guard let urlString = authService.userProfile?.user.images?.avatar?.full,
              let url = URL(string: urlString) else {
            avatarImage = nil
            return
        }
        avatarImage = await ImageService.shared.load(url: url)
    }
}
