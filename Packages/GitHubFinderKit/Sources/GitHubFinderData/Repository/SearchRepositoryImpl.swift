/*
 Abstract:
 リモートAPIとメモリキャッシュを統合する検索リポジトリの実装。
 */

import Foundation
import GitHubFinderDomain

public final class SearchRepositoryImpl: SearchRepositoryProtocol, Sendable {
    private let remoteDataSource: GitHubRemoteDataSource
    private let cacheDataSource: SearchCacheDataSource

    public init(
        remoteDataSource: GitHubRemoteDataSource,
        cacheDataSource: SearchCacheDataSource
    ) {
        self.remoteDataSource = remoteDataSource
        self.cacheDataSource = cacheDataSource
    }

    public func search(query: String, page: Int) async throws -> SearchResultEntity {
        if let cached = await cacheDataSource.get(query: query, page: page) {
            return cached
        }

        let dto: SearchResponseDTO
        do {
            dto = try await remoteDataSource.searchRepositories(query: query, page: page)
        } catch let error as AppError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            // `.task(id:)` のキャンセルで URLSession が投げる .cancelled は通信失敗ではないので、キャンセルとして伝播する
            throw CancellationError()
        } catch is URLError {
            // それ以外の URLError は種別を問わず通信失敗として扱う
            throw AppError.network
        } catch is DecodingError {
            throw AppError.decode
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }

        let items = dto.items.map { $0.toEntity() }
        let hasNextPage = page * GitHubRemoteDataSource.perPage < dto.totalCount
        let result = SearchResultEntity(
            totalCount: dto.totalCount,
            items: items,
            hasNextPage: hasNextPage
        )

        await cacheDataSource.set(query: query, page: page, result: result)

        return result
    }
}
