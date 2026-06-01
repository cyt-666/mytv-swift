import SwiftUI

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let user = viewModel.user {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(.quaternary)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                            }

                        Text(user.username)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let name = user.name {
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 60)

                    if let stats = viewModel.stats {
                        VStack(spacing: 16) {
                            Text("统计")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                StatCard(title: "电影观看", value: "\(stats.movies.watched)")
                                StatCard(title: "剧集观看", value: "\(stats.shows.watched)")
                                StatCard(title: "观看时长", value: "\(stats.movies.minutes / 60) 小时")
                                StatCard(title: "收藏", value: "\(stats.movies.collected + stats.shows.collected)")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                } else if !authService.isLoggedIn {
                    LoginWebView()
                } else {
                    ProgressView()
                }
            }
        }
        .task { await viewModel.load() }
    }

    private var authService: AuthService { .shared }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
