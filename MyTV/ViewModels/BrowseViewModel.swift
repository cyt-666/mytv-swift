import Foundation

struct BrowseFilterOption: Hashable, Identifiable {
    let title: String
    let value: String

    var id: String { value }
}

@Observable
@MainActor
final class BrowseViewModel {
    var selectedGenre = ""
    var selectedCountry = ""
    var items: [MovieDTO] = []
    var isLoading = false

    let genres = [
        BrowseFilterOption(title: "动作", value: "action"),
        BrowseFilterOption(title: "冒险", value: "adventure"),
        BrowseFilterOption(title: "动画", value: "animation"),
        BrowseFilterOption(title: "喜剧", value: "comedy"),
        BrowseFilterOption(title: "犯罪", value: "crime"),
        BrowseFilterOption(title: "纪录片", value: "documentary"),
        BrowseFilterOption(title: "剧情", value: "drama"),
        BrowseFilterOption(title: "家庭", value: "family"),
        BrowseFilterOption(title: "奇幻", value: "fantasy"),
        BrowseFilterOption(title: "历史", value: "history"),
        BrowseFilterOption(title: "恐怖", value: "horror"),
        BrowseFilterOption(title: "音乐", value: "music"),
        BrowseFilterOption(title: "悬疑", value: "mystery"),
        BrowseFilterOption(title: "浪漫", value: "romance"),
        BrowseFilterOption(title: "科幻", value: "science-fiction"),
        BrowseFilterOption(title: "电视电影", value: "tv-movie"),
        BrowseFilterOption(title: "惊悚", value: "thriller"),
        BrowseFilterOption(title: "战争", value: "war"),
        BrowseFilterOption(title: "西部", value: "western")
    ]

    let countries = [
        BrowseFilterOption(title: "美国", value: "us"),
        BrowseFilterOption(title: "英国", value: "gb"),
        BrowseFilterOption(title: "中国", value: "cn"),
        BrowseFilterOption(title: "日本", value: "jp"),
        BrowseFilterOption(title: "韩国", value: "kr"),
        BrowseFilterOption(title: "法国", value: "fr"),
        BrowseFilterOption(title: "德国", value: "de"),
        BrowseFilterOption(title: "加拿大", value: "ca"),
        BrowseFilterOption(title: "澳大利亚", value: "au"),
        BrowseFilterOption(title: "印度", value: "in"),
        BrowseFilterOption(title: "意大利", value: "it"),
        BrowseFilterOption(title: "西班牙", value: "es")
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
