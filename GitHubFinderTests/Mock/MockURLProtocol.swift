/*
 Abstract:
 URLSession に差し込むテスト用URLProtocol。
 Swift Testing は Suite を並列実行するため、テストスイートごとに独立した
 static 状態を持つサブクラス（MockURLProtocolForRemote / MockURLProtocolForRepository）を用意し、
 テスト間の状態干渉を防ぐ。
 */

import Foundation

class MockURLProtocolBase: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
}

// MARK: - GitHubRemoteDataSource 用

final class MockURLProtocolForRemote: MockURLProtocolBase {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var callCount: Int = 0

    override func startLoading() {
        MockURLProtocolForRemote.lastRequest = request
        MockURLProtocolForRemote.callCount += 1
        guard let handler = MockURLProtocolForRemote.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    static func makeURLSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocolForRemote.self]
        return URLSession(configuration: config)
    }

    static func reset() {
        requestHandler = nil
        lastRequest = nil
        callCount = 0
    }
}

// MARK: - SearchRepositoryImpl 用

final class MockURLProtocolForRepository: MockURLProtocolBase {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var callCount: Int = 0

    override func startLoading() {
        MockURLProtocolForRepository.lastRequest = request
        MockURLProtocolForRepository.callCount += 1
        guard let handler = MockURLProtocolForRepository.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    static func makeURLSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocolForRepository.self]
        return URLSession(configuration: config)
    }

    static func reset() {
        requestHandler = nil
        lastRequest = nil
        callCount = 0
    }
}
