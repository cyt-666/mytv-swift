import AppKit

actor ImageService {
    static let shared = ImageService()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<NSImage?, Never>] = [:]

    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func getCached(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<NSImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data) else { return nil }
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
