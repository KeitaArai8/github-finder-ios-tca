/*
 Abstract:
 コーチマーク型チュートリアルの Reducer。ステップの進行と完了の保存を担当する。
 State が存在する間がチュートリアル表示中で、完了・スキップ時は delegate で親へ通知する（親が State を破棄する）。
 */

import ComposableArchitecture
import Foundation

@Reducer
public struct TutorialFeature: Sendable {
    /// チュートリアル進行ステップ
    public enum Step: Int, CaseIterable, Sendable {
        case searchBar = 0
        case favoriteButton = 1
        case favoriteTab = 2

        public var title: String {
            switch self {
            case .searchBar: String(localized: "検索してみよう", bundle: #bundle)
            case .favoriteButton: String(localized: "お気に入りに追加", bundle: #bundle)
            case .favoriteTab: String(localized: "お気に入り一覧", bundle: #bundle)
            }
        }

        public var description: String {
            switch self {
            case .searchBar: String(localized: "キーワードを入力して\nGitHubリポジトリを検索できます", bundle: #bundle)
            case .favoriteButton: String(localized: "ハートボタンをタップして\nお気に入りに追加しましょう", bundle: #bundle)
            case .favoriteTab: String(localized: "お気に入りタブから\n保存したリポジトリを確認できます", bundle: #bundle)
            }
        }

        public var systemImage: String {
            switch self {
            case .searchBar: "magnifyingglass"
            case .favoriteButton: "heart.fill"
            case .favoriteTab: "star.fill"
            }
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var currentStep: Step = .searchBar

        public init() {}
    }

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        @CasePathable
        public enum Delegate {
            /// 最後のステップを終えた、またはスキップされた
            case completed
        }

        @CasePathable
        public enum View {
            case nextButtonTapped
            case skipButtonTapped
            /// ステップの対象 UI（検索バー・ハートボタン・お気に入りタブのモック）がタップされた
            case targetTapped(Step)
        }
    }

    @Dependency(\.tutorialClient) var tutorialClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.nextButtonTapped):
                return advance(&state)

            case .view(.skipButtonTapped):
                return complete()

            case .view(.targetTapped(let step)):
                // 現在のステップの対象以外をタップしても進めない
                guard state.currentStep == step else { return .none }
                return advance(&state)

            case .delegate:
                return .none
            }
        }
    }

    private func advance(_ state: inout State) -> Effect<Action> {
        guard let nextStep = Step(rawValue: state.currentStep.rawValue + 1) else {
            return complete()
        }
        state.currentStep = nextStep
        return .none
    }

    private func complete() -> Effect<Action> {
        .run { send in
            tutorialClient.markCompleted()
            await send(.delegate(.completed))
        }
    }
}
