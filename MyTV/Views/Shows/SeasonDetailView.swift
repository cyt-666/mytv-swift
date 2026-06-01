import SwiftUI

struct SeasonDetailView: View {
    let showId: Int
    let seasonNumber: Int
    @State private var viewModel: SeasonDetailViewModel?

    var body: some View {
        Group {
            if let viewModel, !viewModel.isLoading || !viewModel.episodes.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.episodes, id: \.number) { episode in
                            EpisodeRow(episode: episode, showId: showId, seasonNumber: seasonNumber)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = SeasonDetailViewModel(showId: showId, seasonNumber: seasonNumber)
            self.viewModel = vm
            await vm.load()
        }
    }
}

private struct EpisodeRow: View {
    let episode: EpisodeDTO
    let showId: Int
    let seasonNumber: Int
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.navigate(
                to: .episodeDetail(
                    showId: showId,
                    seasonNumber: seasonNumber,
                    episodeNumber: episode.number
                )
            )
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: 100, height: 56)
                    .overlay {
                        Image(systemName: "play.fill").foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("E\(episode.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(episode.title ?? "")
                        .font(.body)
                        .lineLimit(2)
                }

                Spacer()

                if let rating = episode.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
