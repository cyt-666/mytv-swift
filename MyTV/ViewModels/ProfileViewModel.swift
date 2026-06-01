import Foundation

@Observable
@MainActor
final class ProfileViewModel {
    var user: UserDTO?
    var stats: UserStatsDTO?
    var isLoading = false

    func load() async {
        guard AuthService.shared.isLoggedIn else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            async let profileResult = UserAPI.profile()
            async let statsResult = UserAPI.stats()
            let (profile, statsData) = try await (profileResult, statsResult)
            user = profile.user
            stats = statsData
        } catch {
            print("加载用户信息失败: \(error)")
        }
    }
}
