/*
 Abstract:
 GitHubリポジトリのページURLをfullNameから安全に構築するヘルパー。
 URLComponentsを経由することで、fullNameに含まれる特殊文字を自動的にpercent-encodeする。
 */

import Foundation

public nonisolated func makeGitHubURL(fullName: String) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "github.com"
    components.path = "/" + fullName
    return components.url
}
