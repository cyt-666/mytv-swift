import SwiftUI

struct RecommendationsView: View {
    let type: String // "movies" or "shows"
    @State private var movies: [MovieDTO] = []
    @State private var shows: [ShowDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var title: String { type == "movies" ? "推荐电影" : "推荐剧集" }

    var body: some View {
        Group {
            if isLoading && movies.isEmpty && shows.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Text(error)
                } actions: {
                    Button("重试") { Task { await load() } }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(title)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.horizontal, 20)
                            .padding(.top, 60)

                        MediaGridView(items: items)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: isLoading)
                }
                .disabled(isLoading)
                .help("刷新")
            }
        }
    }

    private var items: [MediaItem] {
        if type == "movies" {
            return movies.map { .movie($0) }
        } else {
            return shows.map { .show($0) }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if type == "movies" {
                movies = try await RecommendationAPI.movies()
            } else {
                shows = try await RecommendationAPI.shows()
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
}
