/*
 Abstract:
 NWPathMonitor の AsyncSequence を購読し、ネットワーク接続状態を @Observable で公開する。
 オフライン時は OfflineBanner を表示するために UI 層で観察される。
 購読は View の `.task` から `start()` を呼んで開始し、View の消滅（Task キャンセル）で止まる。
 */

import Foundation
import Network
import os
import GitHubFinderDomain

@Observable
@MainActor
public final class NetworkMonitor {
    public private(set) var isConnected: Bool = true

    public init() {}

    /// 経路の変化を監視し続ける。呼び出し元の Task がキャンセルされると監視も終了する。
    public func start() async {
        for await path in NWPathMonitor() {
            let connected = path.status == .satisfied
            if isConnected != connected {
                isConnected = connected
                Logger.network.info("Network state changed: connected=\(connected, privacy: .public)")
            }
        }
    }
}
