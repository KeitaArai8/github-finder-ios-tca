/*
 Abstract:
 スポットライト型のチュートリアルオーバーレイ。
 暗転背景に対象UIの位置だけ穴を空け、パルスリングで強調しつつ吹き出しで説明する。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct CoachMarkOverlay: View {
    let step: TutorialFeature.Step
    let frames: [TutorialFeature.Step: CGRect]
    let onNext: () -> Void
    let onSkip: () -> Void

    private let spotlightPadding: CGFloat = 12
    private let spotlightCornerRadius: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let targetFrame = resolvedFrame(in: geo.size)
            let spotlightRect = targetFrame.insetBy(dx: -spotlightPadding, dy: -spotlightPadding)

            ZStack(alignment: .topLeading) {
                dimmedBackground(spotlightRect: spotlightRect)
                    .animation(stepAnimation, value: step)
                    .onTapGesture { onNext() }

                PulseRing()
                    .frame(width: spotlightRect.width, height: spotlightRect.height)
                    .position(x: spotlightRect.midX, y: spotlightRect.midY)
                    .animation(stepAnimation, value: step)
                    .allowsHitTesting(false)

                GlassEffectContainer {
                    tooltipCard
                }
                .frame(maxWidth: geo.size.width - 48)
                .position(tooltipPosition(target: targetFrame, in: geo.size))
                .animation(stepAnimation, value: step)

                skipButton
                    .position(x: geo.size.width - 48, y: 60)
            }
        }
        .ignoresSafeArea()
    }

    /// ステップ切り替え時に動く要素（スポットライト・リング・吹き出し）にだけ付ける。
    /// GeometryReader 全体に付けると、スキップボタンなど動かない要素まで対象になる。
    private var stepAnimation: Animation { .easeInOut(duration: 0.25) }

    // MARK: - Background

    private func dimmedBackground(spotlightRect: CGRect) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.75))
            .reverseMask {
                RoundedRectangle(cornerRadius: spotlightCornerRadius)
                    .frame(width: spotlightRect.width, height: spotlightRect.height)
                    .position(x: spotlightRect.midX, y: spotlightRect.midY)
            }
    }

    // MARK: - Tooltip

    private var tooltipCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: step.systemImage)
                    .font(.headline)
                    .foregroundStyle(.blue)
                Text(step.title)
                    .font(.headline)
            }
            Text(step.description)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                stepIndicator
                Spacer()
                Button {
                    onNext()
                } label: {
                    Text(isLastStep ? LocalizedStringResource("はじめる", bundle: #bundle) : LocalizedStringResource("次へ", bundle: #bundle))
                        .font(.subheadline.bold())
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(16)
        // 吹き出しはコンテンツの上に浮く操作要素なので Liquid Glass。ボタンの glass と融合させるため同じ container に入れる
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.radius200))
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(TutorialFeature.Step.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(s == step ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button(LocalizedStringResource("スキップ", bundle: #bundle)) {
            onSkip()
        }
        .font(.caption.bold())
        .foregroundStyle(Color(.label))
        .buttonStyle(.glass)
    }

    // MARK: - Positioning

    /// 対象UIの矩形。未取得の場合はステップごとにフォールバック位置を返す。
    private func resolvedFrame(in screen: CGSize) -> CGRect {
        if let frame = frames[step], frame.width > 0, frame.height > 0 {
            return frame
        }
        return fallbackFrame(in: screen)
    }

    /// 対象UIの矩形がまだ取得できていない場合のフォールバック。
    /// 検索バーはナビゲーションバー付近、タブは画面下部など、役割に応じた近似位置を返す。
    private func fallbackFrame(in screen: CGSize) -> CGRect {
        switch step {
        case .searchBar:
            // NavigationTitle 直下の searchable TextField を想定した矩形
            return CGRect(x: 16, y: 180, width: screen.width - 32, height: 40)
        case .favoriteButton:
            // リスト内先頭行のハートボタン位置を想定
            return CGRect(x: screen.width - 70, y: 260, width: 44, height: 44)
        case .favoriteTab:
            let tabWidth = screen.width / 3
            return CGRect(x: tabWidth, y: screen.height - 90, width: tabWidth, height: 50)
        }
    }

    /// 吹き出しの位置を対象UIの矩形から決定する。
    /// 対象が画面上半分にあるときは吹き出しを下、下半分にあるときは上に配置する。
    private func tooltipPosition(target: CGRect, in screen: CGSize) -> CGPoint {
        let verticalGap: CGFloat = 24
        let tooltipHeight: CGFloat = 140
        let isUpperHalf = target.midY < screen.height / 2

        let y: CGFloat = isUpperHalf
            ? target.maxY + verticalGap + tooltipHeight / 2
            : target.minY - verticalGap - tooltipHeight / 2

        let clampedY = min(max(y, tooltipHeight / 2 + 16), screen.height - tooltipHeight / 2 - 16)
        return CGPoint(x: screen.width / 2, y: clampedY)
    }

    private var isLastStep: Bool {
        step == TutorialFeature.Step.allCases.last
    }
}
