/*
 Abstract:
 依存クライアントの処理を、テストが開くまで待たせるゲート。
 `@Shared` の State は参照なので、Effect の応答が `store.send` の assert より先に処理されると、
 まだ起きていないはずの変更が assert 時点の State に見えてしまう。応答が共有 State を書き換えるテストでは、
 クライアントのクロージャの先頭で `wait()` し、`store.send` の assert が終わってから `open()` する。
 */

final class EffectGate: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    }

    /// `open()` が呼ばれるまで待つ。開いた後は待たずに戻る
    func wait() async {
        for await _ in stream {}
    }

    /// 待機中および以降の `wait()` をすべて通す
    func open() {
        continuation.finish()
    }
}
