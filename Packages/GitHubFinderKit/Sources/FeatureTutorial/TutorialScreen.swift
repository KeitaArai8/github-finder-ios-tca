/*
 Abstract:
 初回起動時に表示するチュートリアル専用画面。
 SearchView のレイアウトをモックで再現し、各UIに .coachMarkAnchor を付与する。
 本機能側の実装には一切手を入れず、チュートリアル進行は TutorialScreen 内の
 モック操作（TextField タップ・ハートタップ・タブタップ）から発火させる。
 */

import SwiftUI
import ComposableArchitecture
import GitHubFinderDesignSystem

@ViewAction(for: TutorialFeature.self)
public struct TutorialScreen: View {
    public let store: StoreOf<TutorialFeature>

    @State private var coachMarkFrames: [TutorialFeature.Step: CGRect] = [:]

    private let mockRepo = MockRepository(
        fullName: "apple/swift",
        description: "The Swift Programming Language",
        starCount: 67_000,
        language: "C++"
    )

    public init(store: StoreOf<TutorialFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                headerTitle
                mockSearchBar
                mockRepositoryRow
                    .padding(.top, 24)
                Spacer()
                mockTabBar
            }

            CoachMarkOverlay(
                step: store.currentStep,
                frames: coachMarkFrames,
                onNext: { send(.nextButtonTapped) },
                onSkip: { send(.skipButtonTapped) }
            )
        }
        .onPreferenceChange(CoachMarkFramePreferenceKey.self) { frames in
            coachMarkFrames = frames
        }
    }

    // MARK: - Mock UI

    private var headerTitle: some View {
        HStack {
            Text("検索", bundle: #bundle)
                .font(.largeTitle.bold())
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var mockSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text("リポジトリを検索", bundle: #bundle)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .coachMarkAnchor(for: .searchBar)
        .contentShape(Rectangle())
        .onTapGesture {
            send(.targetTapped(.searchBar))
        }
    }

    private var mockRepositoryRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Color.gray.opacity(0.25)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: Radius.radius100))

            VStack(alignment: .leading, spacing: 4) {
                Text(mockRepo.fullName)
                    .font(.headline)
                Text(mockRepo.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Label("\(mockRepo.starCount)", systemImage: "star.fill")
                        .foregroundStyle(.orange)
                    Text(mockRepo.language)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            Button {
                send(.targetTapped(.favoriteButton))
            } label: {
                Image(systemName: "heart")
                    .font(.title3)
                    .foregroundStyle(.gray)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .coachMarkAnchor(for: .favoriteButton)
        }
        .padding(.horizontal, 16)
    }

    private var mockTabBar: some View {
        // 実機の iOS 26 タブバーと同じ並び: お気に入り・設定が 1 つのカプセル、検索（role: .search）は右端に独立した丸
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    tabItem(systemImage: "heart.fill", label: LocalizedStringResource("お気に入り", bundle: #bundle), isSelected: false) {
                        send(.targetTapped(.favoriteTab))
                    }
                    .coachMarkAnchor(for: .favoriteTab)

                    tabItem(systemImage: "gearshape", label: LocalizedStringResource("設定", bundle: #bundle), isSelected: false) {}
                }
                .frame(height: 56)
                // iOS 26 のタブバーは画面下端に浮くガラスのカプセル。material の帯ではなく同じ見た目に揃える
                .glassEffect(.regular, in: .capsule)

                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular, in: .circle)
                    .accessibilityLabel(Text("検索", bundle: #bundle))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabItem(
        systemImage: String,
        label: LocalizedStringResource,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mock Data

    private struct MockRepository {
        let fullName: String
        let description: String
        let starCount: Int
        let language: String
    }
}
