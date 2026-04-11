import Foundation

/// Obtiene la URL de miniatura de la API de Wikipedia (pageimages), p. ej.
/// `https://en.wikipedia.org/w/api.php?action=query&titles=Albert_Einstein&prop=pageimages&format=json&pithumbsize=800`
enum WikipediaThumbnailService {
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 18
        c.timeoutIntervalForResource = 30
        return URLSession(configuration: c)
    }()

    /// Identificación requerida por la política de uso de la API de Wikimedia.
    private static let userAgent = "AeroStudy/1.0 (educational iOS app; contact via app support)"

    private actor Cache {
        /// `nil` en el diccionario = aún no consultado; `URL?.none` codificado como sentinela no aplica; usamos `Optional<URL?>` vía enum.
        enum Entry {
            case miss
            case hit(URL)
        }

        var entries: [String: Entry] = [:]

        func get(_ key: String) -> Entry? { entries[key] }
        func setMiss(_ key: String) { entries[key] = .miss }
        func setHit(_ key: String, url: URL) { entries[key] = .hit(url) }
    }

    private static let cache = Cache()

    /// Devuelve la URL de la miniatura si existe un artículo con imagen; si no, `nil`.
    static func thumbnailURL(for studyTitle: String) async -> URL? {
        let key = studyTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        switch await cache.get(key) {
        case .miss:
            return nil
        case .hit(let url):
            return url
        case nil:
            break
        }

        guard let request = makeRequest(for: key) else {
            await cache.setMiss(key)
            return nil
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                await cache.setMiss(key)
                return nil
            }
            guard let url = parseThumbnailJSON(data) else {
                await cache.setMiss(key)
                return nil
            }
            await cache.setHit(key, url: url)
            return url
        } catch {
            await cache.setMiss(key)
            return nil
        }
    }

    private static func makeRequest(for title: String) -> URLRequest? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "pithumbsize", value: "800"),
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func parseThumbnailJSON(_ data: Data) -> URL? {
        struct Root: Decodable {
            let query: Query?
        }
        struct Query: Decodable {
            let pages: [String: Page]
        }
        struct Page: Decodable {
            let thumbnail: Thumb?
            let missing: Bool?
        }
        struct Thumb: Decodable {
            let source: String
        }

        guard let root = try? JSONDecoder().decode(Root.self, from: data),
              let pages = root.query?.pages
        else { return nil }

        for (_, page) in pages {
            if page.missing == true { continue }
            if let source = page.thumbnail?.source, let u = URL(string: source) {
                return u
            }
        }
        return nil
    }
}
