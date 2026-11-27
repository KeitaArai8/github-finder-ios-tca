/*
 Abstract:
 アプリケーション全体で使用するドメインエラー型。
 */

import Foundation

public enum AppError: Error, Equatable, LocalizedError {
    case network
    case server(statusCode: Int)
    case rateLimit
    case decode
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .network:
            String(localized: "ネットワークに接続できません", bundle: #bundle)
        case .server(let statusCode):
            String(localized: "サーバーエラーが発生しました（\(statusCode)）", bundle: #bundle)
        case .rateLimit:
            String(localized: "API制限に達しました。しばらく待ってから再試行してください", bundle: #bundle)
        case .decode:
            String(localized: "データの読み込みに失敗しました", bundle: #bundle)
        case .unknown(let message):
            message
        }
    }
}
