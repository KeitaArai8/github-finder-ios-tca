/*
 Abstract:
 設定画面の Reducer。法的情報のリンクを Safari シートで開く。
 */

import Foundation
import ComposableArchitecture
import GitHubFinderDesignSystem

@Reducer
public struct SettingsFeature: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case safari(SafariDestination)
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var destination: Destination.State?

        public init() {}
    }

    public enum Action: ViewAction {
        case destination(PresentationAction<Destination.Action>)
        case view(View)

        @CasePathable
        public enum View {
            case privacyPolicyTapped
            case termsTapped
        }
    }

    static let privacyPolicyURL = URL(string: "https://www.apple.com/legal/privacy/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/")!

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.privacyPolicyTapped):
                state.destination = .safari(SafariDestination(url: Self.privacyPolicyURL))
                return .none

            case .view(.termsTapped):
                state.destination = .safari(SafariDestination(url: Self.termsURL))
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension SettingsFeature.Destination.State: Equatable {}
