import Foundation

@Observable
@MainActor
final class BrowseViewModel {
    var selectedGenre = ""
    var selectedCountry = ""
    var items: [MovieDTO] = []
    var isLoading = false

    let genres = [
        "动作", "冒险", "动画", "喜剧", "犯罪", "纪录片", "剧情",
        "家庭", "奇幻", "历史", "恐怖", "音乐", "悬疑", "浪漫",
        "科幻", "电视电影", "惊悚", "战争", "西部"
    ]

    let countries = [
        "美国", "英国", "中国", "日本", "韩国", "法国", "德国",
        "加拿大", "澳大利亚", "印度", "意大利", "西班牙"
    ]

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let genre = selectedGenre.isEmpty ? nil : selectedGenre
        let country = selectedCountry.isEmpty ? nil : selectedCountry

        do {
            let result = try await MovieAPI.popular(limit: 30, genres: genre, countries: country)
            items = result
        } catch {
            print("加载分类数据失败: \(error)")
        }
    }
}
