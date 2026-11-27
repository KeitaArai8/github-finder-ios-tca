/*
 Abstract:
 画面の表示状態を5つの状態で管理する汎用enum。
 */

public nonisolated enum ViewState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case empty
    case error(String)
}
