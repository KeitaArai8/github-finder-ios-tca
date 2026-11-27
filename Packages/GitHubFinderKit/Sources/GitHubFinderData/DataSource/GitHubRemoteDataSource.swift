/*
 Abstract:
 GitHub APIとの通信を担当するリモートデータソース。
 */

import Foundation
import GitHubFinderDomain

/// 保持するのは不変の `let` のみなので actor ではなく Sendable な struct にする（直列化が不要）
public struct GitHubRemoteDataSource: Sendable {
    private let session: URLSession
    private let baseURL = "https://api.github.com"
    /// 1ページあたりの取得件数。`hasNextPage` の算出（SearchRepositoryImpl）と共有する。
    static let perPage = 30
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    func searchRepositories(query: String, page: Int) async throws -> SearchResponseDTO {
        guard var components = URLComponents(string: "\(baseURL)/search/repositories") else {
            throw AppError.unknown("Invalid URL")
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(Self.perPage)"),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "order", value: "desc"),
        ]
        guard let url = components.url else {
            throw AppError.unknown("Invalid URL components")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network
        }

        switch httpResponse.statusCode {
        case 200:
            return try decoder.decode(SearchResponseDTO.self, from: data)
        case 403:
            throw AppError.rateLimit
        case 400...599:
            throw AppError.server(statusCode: httpResponse.statusCode)
        default:
            throw AppError.unknown("Unexpected status code: \(httpResponse.statusCode)")
        }
    }
}
