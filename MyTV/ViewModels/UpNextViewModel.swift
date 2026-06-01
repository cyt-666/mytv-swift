import Foundation

@Observable
@MainActor
final class UpNextViewModel {
    var items: [UpNextItemDTO] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        guard AuthService.shared.isLoggedIn else {
            errorMessage = "请先登录"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await ProgressAPI.upNext()
        } catch {
            print("加载待看失败: \(error)")
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
}
