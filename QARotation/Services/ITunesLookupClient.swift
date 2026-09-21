import Foundation

/// 스토어에서 읽어 온 앱 한 개. 스토어가 주인인 값만 담는다.
struct StoreApp: Sendable, Equatable {
    let appStoreID: String
    let bundleID: String
    let name: String
    let iconURL: String
    let version: String
    let platforms: [Platform]
}

struct ITunesLookupClient: Sendable {
    var session: URLSession = .shared

    enum LookupError: LocalizedError {
        case badResponse(Int)
        case noApps

        var errorDescription: String? {
            switch self {
            case .badResponse(let code): "App Store 응답이 올바르지 않아요 (HTTP \(code))."
            case .noApps: "이 개발자 ID로 찾은 앱이 없어요. 설정의 artistId를 확인해 주세요."
            }
        }
    }

    /// 여러 스토어를 차례로 조회해 합친다. 같은 앱이면 앞 스토어(보통 kr)의 이름을 쓴다.
    func fetchApps(artistID: String, storefronts: [String]) async throws -> [StoreApp] {
        var byID: [String: StoreApp] = [:]
        var order: [String] = []
        var lastError: Error?

        for country in storefronts.isEmpty ? [""] : storefronts {
            do {
                for app in try await fetch(artistID: artistID, country: country) where byID[app.appStoreID] == nil {
                    byID[app.appStoreID] = app
                    order.append(app.appStoreID)
                }
            } catch {
                lastError = error
            }
        }

        if order.isEmpty {
            throw lastError ?? LookupError.noApps
        }
        return order.compactMap { byID[$0] }
    }

    private func fetch(artistID: String, country: String) async throws -> [StoreApp] {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: artistID),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "limit", value: "200"),
        ]
        if !country.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "country", value: country))
        }
        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LookupError.badResponse(http.statusCode)
        }
        return try Self.parse(data)
    }

    // MARK: - 파싱

    private struct Response: Decodable {
        let results: [Item]
    }

    private struct Item: Decodable {
        let wrapperType: String?
        let kind: String?
        let trackId: Int?
        let trackName: String?
        let bundleId: String?
        let artworkUrl512: String?
        let artworkUrl100: String?
        let version: String?
        let supportedDevices: [String]?
    }

    static func parse(_ data: Data) throws -> [StoreApp] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.results.compactMap { item in
            // 첫 결과는 개발자(artist) 자신이다.
            guard item.wrapperType == "software", let trackId = item.trackId, let name = item.trackName else { return nil }
            return StoreApp(
                appStoreID: String(trackId),
                bundleID: item.bundleId ?? "",
                name: name,
                iconURL: item.artworkUrl512 ?? item.artworkUrl100 ?? "",
                version: item.version ?? "",
                platforms: platforms(kind: item.kind, devices: item.supportedDevices ?? [])
            )
        }
    }

    static func platforms(kind: String?, devices: [String]) -> [Platform] {
        var result: [Platform] = []
        if kind == "mac-software" { result.append(.mac) }
        if devices.contains(where: { $0.hasPrefix("iPhone") }) { result.append(.iPhone) }
        if devices.contains(where: { $0.hasPrefix("iPad") }) { result.append(.iPad) }
        if devices.contains(where: { $0.hasPrefix("Watch") }) { result.append(.watch) }
        if devices.contains(where: { $0.hasPrefix("AppleTV") }) { result.append(.tv) }
        if devices.contains(where: { $0.hasPrefix("RealityDevice") || $0.hasPrefix("AppleVision") }) { result.append(.vision) }
        return result
    }
}
