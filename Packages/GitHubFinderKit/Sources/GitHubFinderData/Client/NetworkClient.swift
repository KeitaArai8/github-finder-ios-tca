/*
 Abstract:
 ネットワーク接続状態の変化を Reducer へ公開する依存クライアント。
 本番実装は NetworkMonitor（NWPathMonitor の購読）の薄いラッパー。
 */

import Dependencies
import DependenciesMacros
import Observation

@DependencyClient
public struct NetworkClient: Sendable {
    /// 接続状態（true = 接続中）を、現在値から始めて変化のたびに流すストリーム。
    /// ストリームの購読をやめると監視も止まる
    public var connectivity: @Sendable () async -> AsyncStream<Bool> = { AsyncStream { $0.finish() } }
}

extension NetworkClient: DependencyKey {
    public static let liveValue = NetworkClient(
        connectivity: {
            AsyncStream { continuation in
                let task = Task { @MainActor in
                    let monitor = NetworkMonitor()
                    // 経路の監視（isConnected の更新）と、その値の配信を並行して走らせる
                    async let monitoring: Void = monitor.start()
                    for await isConnected in Observations({ monitor.isConnected }) {
                        continuation.yield(isConnected)
                    }
                    await monitoring
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )

    public static let testValue = NetworkClient()
}

extension DependencyValues {
    public var networkClient: NetworkClient {
        get { self[NetworkClient.self] }
        set { self[NetworkClient.self] = newValue }
    }
}
