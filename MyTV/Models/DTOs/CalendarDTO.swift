import Foundation

struct CalendarMovieDTO: Codable, Identifiable {
    let released: String?
    let movie: MovieDTO

    var id: Int { movie.ids.trakt }
}

struct CalendarShowDTO: Codable, Identifiable {
    let firstAired: String?
    let episode: EpisodeDTO?
    let show: ShowDTO

    var id: String {
        "\(show.ids.trakt)_\(episode?.season ?? 0)_\(episode?.number ?? 0)"
    }

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case episode, show
    }
}
