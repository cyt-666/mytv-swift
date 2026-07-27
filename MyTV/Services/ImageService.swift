import Foundation

@MainActor
final class ImageService {
    static let shared = ImageService()

    private let cache = NSCache<NSURL, PlatformImage>()
    private var inFlight: [URL: Task<PlatformImage?, Never>] = [:]

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func getCached(for url: URL) -> PlatformImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(url: URL) async -> PlatformImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<PlatformImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = PlatformImage(data: data) else { return nil }
            cache.setObject(image, forKey: url as NSURL, cost: data.count)
            return image
        }

        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        return result
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
