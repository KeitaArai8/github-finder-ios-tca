/*
 Abstract:
 SFSafariViewControllerをSwiftUIで使用するためのラッパー。
 検索 / お気に入り / 設定の 3 画面から共通利用されるため DesignSystem に配置。
 */

import SafariServices
import SwiftUI

/// `sheet(item:)` で SafariView を出すための URL ラッパー。
/// 検索 / お気に入り / 設定の 3 画面で共通利用する。
public nonisolated struct SafariDestination: Identifiable, Hashable {
    public let url: URL
    public var id: URL { url }

    public init(url: URL) {
        self.url = url
    }
}

public struct SafariView: UIViewControllerRepresentable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
