/*
 Abstract:
 アプリのルート Reducer。検索・お気に入り・設定の 3 タブの Reducer を束ね、
 初回起動時のチュートリアル表示と、ネットワーク接続状態（オフラインバナー）を管理する。
 */

import ComposableArchitecture
import GitHubFinderDomain
import GitHubFinderData
import FeatureSearch
import FeatureFavorite
import FeatureSettings
import FeatureTutorial

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var search: SearchFeature.State
        var favorite: FavoriteFeature.State
        var settings = SettingsFeature.State()
        /// 非 nil の間はチュートリアルを表示する（完了・スキップで nil に戻す）
        var tutorial: TutorialFeature.State?
        var isConnected = true

        init() {
            // お気に入り一覧は検索画面とお気に入り画面で 1 つの共有 State を参照する
            let favorites = Shared(value: [FavoriteEntity]())
            search = SearchFeature.State(favorites: favorites)
            favorite = FavoriteFeature.State(favorites: favorites)
        }
    }

    enum Action: ViewAction {
        case favorite(FavoriteFeature.Action)
        case `internal`(Internal)
        case search(SearchFeature.Action)
        case settings(SettingsFeature.Action)
        case tutorial(TutorialFeature.Action)
        case view(View)

        @CasePathable
        enum Internal {
            case connectivityChanged(Bool)
        }

        @CasePathable
        enum View {
            case task
        }
    }

    @Dependency(\.networkClient) var networkClient
    @Dependency(\.tutorialClient) var tutorialClient

    var body: some ReducerOf<Self> {
        Scope(\.search, action: \.search) {
            SearchFeature()
        }
        Scope(\.favorite, action: \.favorite) {
            FavoriteFeature()
        }
        Scope(\.settings, action: \.settings) {
            SettingsFeature()
        }

        Reduce { state, action in
            switch action {
            case .view(.task):
                if !tutorialClient.hasCompleted() {
                    state.tutorial = TutorialFeature.State()
                }
                return .run { send in
                    for await isConnected in await networkClient.connectivity() {
                        await send(.internal(.connectivityChanged(isConnected)))
                    }
                }

            case .internal(.connectivityChanged(let isConnected)):
                state.isConnected = isConnected
                return .none

            case .tutorial(.delegate(.completed)):
                state.tutorial = nil
                return .none

            case .favorite, .search, .settings, .tutorial:
                return .none
            }
        }
        .ifLet(\.tutorial, action: \.tutorial) {
            TutorialFeature()
        }
    }
}
