/*
 Abstract:
 GitHub Finderのお気に入り上位5件をホーム画面に表示するWidget。
 App Group経由で共有されるSwiftData ModelContainerからデータを取得する。
 Small/Medium/Large の 3 サイズをサポート。
 */

import WidgetKit
import SwiftUI
import SwiftData
import GitHubFinderDomain
import GitHubFinderData

// MARK: - Timeline Entry

struct FavoriteTimelineEntry: TimelineEntry {
    let date: Date
    let favorites: [FavoriteEntity]
}

// MARK: - Timeline Provider

struct FavoriteTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoriteTimelineEntry {
        FavoriteTimelineEntry(date: Date(), favorites: [])
    }

    // TimelineProvider に async 版の要件は無い（snapshot(for:in:) / timeline(for:in:) は
    // AppIntentTimelineProvider 専用）。設定 Intent を持たない StaticConfiguration のため completion 版を維持する
    func getSnapshot(in context: Context, completion: @escaping (FavoriteTimelineEntry) -> Void) {
        let favorites = loadFavorites()
        completion(FavoriteTimelineEntry(date: Date(), favorites: favorites))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoriteTimelineEntry>) -> Void) {
        let favorites = loadFavorites()
        let entry = FavoriteTimelineEntry(date: Date(), favorites: favorites)
        // 1時間後の更新時刻。nil はカレンダー算出失敗時のみなので 3600秒 加算にフォールバック
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func loadFavorites() -> [FavoriteEntity] {
        // App Group設定不備でもWidgetをクラッシュさせず空状態にフォールバックする
        guard let container = try? AppGroupContainer.makeModelContainer() else {
            return []
        }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<FavoriteRecord>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map { $0.toEntity() }
    }
}

// MARK: - Entry View

struct FavoriteWidgetEntryView: View {
    var entry: FavoriteTimelineEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            smallView
        default:
            listView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if let top = entry.favorites.first {
                Text(top.fullName)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                starLabel(count: top.starCount)
            } else {
                emptyLabel
            }
        }
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.favorites.isEmpty {
                Spacer()
                emptyLabel
                Spacer()
            } else {
                ForEach(entry.favorites.prefix(widgetFamily == .systemLarge ? 5 : 3), id: \.id) { item in
                    row(for: item)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .widgetAccentable()
            Text("お気に入り")
                .font(.caption)
                .foregroundStyle(.secondary)
                .widgetAccentable()
        }
    }

    private var emptyLabel: some View {
        Text("お気に入りがありません")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func row(for item: FavoriteEntity) -> some View {
        HStack(spacing: 6) {
            Text(item.fullName)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            starLabel(count: item.starCount)
        }
    }

    private func starLabel(count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .foregroundStyle(.orange)
                .widgetAccentable()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

// MARK: - Widget Configuration

struct FavoriteWidget: Widget {
    let kind: String = AppGroupContainer.favoriteWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoriteTimelineProvider()) { entry in
            FavoriteWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("お気に入り")
        .description("GitHub Finderのお気に入りを表示します")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    FavoriteWidget()
} timeline: {
    FavoriteTimelineEntry(date: .now, favorites: [])
    FavoriteTimelineEntry(
        date: .now,
        favorites: [
            FavoriteEntity(
                id: 1,
                fullName: "apple/swift",
                description: nil,
                starCount: 67000,
                language: "C++",
                ownerAvatarURL: nil,
                savedAt: .now
            ),
            FavoriteEntity(
                id: 2,
                fullName: "pointfreeco/swift-composable-architecture",
                description: nil,
                starCount: 13000,
                language: "Swift",
                ownerAvatarURL: nil,
                savedAt: .now
            ),
        ]
    )
}
