/*
 Abstract:
 ViewState<T> 5 状態の網羅性をカタログ表示する。
 */

import SwiftUI
import GitHubFinderDesignSystem

struct ViewStateCatalog: View {
    private let allStates: [(label: String, state: ViewState<[String]>)] = [
        ("idle", .idle),
        ("loading", .loading),
        ("loaded(items)", .loaded(["A", "B", "C"])),
        ("empty", .empty),
        ("error(message)", .error("ネットワークに接続できません")),
    ]

    var body: some View {
        List {
            Section("State 一覧") {
                ForEach(allStates, id: \.label) { entry in
                    HStack {
                        Text(entry.label)
                            .font(.subheadline.monospaced())
                        Spacer()
                        Text(stateDescription(entry.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Switch 網羅例") {
                Text("ViewState は generic enum で 5 ケース。switch で全ケース網羅を強制できる。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ViewState<T>")
    }

    private func stateDescription(_ state: ViewState<[String]>) -> String {
        switch state {
        case .idle: "初期状態"
        case .loading: "読み込み中"
        case .loaded(let items): "loaded × \(items.count)"
        case .empty: "0 件"
        case .error(let msg): "error: \(msg.prefix(10))…"
        }
    }
}

#Preview {
    NavigationStack { ViewStateCatalog() }
}
