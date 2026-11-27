/*
 Abstract:
 チュートリアル表示済みフラグの読み書きを Reducer へ公開する依存クライアント。
 本番実装は TutorialLocalDataSource（UserDefaults）の薄いラッパー。
 */

import ComposableArchitecture

@DependencyClient
public struct TutorialClient: Sendable {
    /// チュートリアルを完了（またはスキップ）済みか
    public var hasCompleted: @Sendable () -> Bool = { false }
    /// チュートリアルを完了済みとして保存する
    public var markCompleted: @Sendable () -> Void
}

extension TutorialClient: DependencyKey {
    public static let liveValue = TutorialClient(
        hasCompleted: { TutorialLocalDataSource().hasCompleted },
        markCompleted: { TutorialLocalDataSource().markCompleted() }
    )

    public static let testValue = TutorialClient()
}

extension DependencyValues {
    public var tutorialClient: TutorialClient {
        get { self[TutorialClient.self] }
        set { self[TutorialClient.self] = newValue }
    }
}
