import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var results: [MediaItem] = []
    var isLoading = false

    func search(query: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let searchResults = try await SearchAPI.search(query: query, limit: 30)
            results = searchResults.compactMap { result in
                if let movie = result.movie {
                    return MediaItem.movie(movie)
                } else if let show = result.show {
                    return MediaItem.show(show)
                }
                return nil
            }
        } catch {
            print("搜索失败: \(error)")
        }
    }
}
