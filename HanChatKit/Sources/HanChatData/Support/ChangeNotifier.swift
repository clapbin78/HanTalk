import Foundation

/// 로컬 저장소 변경을 관찰자에게 알리는 초경량 이벤트 버스.
/// key 예: "messages:{roomID}", "rooms", "friends"
actor ChangeNotifier {
    private var continuations: [String: [UUID: AsyncStream<Void>.Continuation]] = [:]

    func stream(for key: String) -> AsyncStream<Void> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        continuations[key, default: [:]][id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(key: key, id: id) }
        }
        continuation.yield(()) // 최초 1회 즉시 발행 (현재 상태 로드 유도)
        return stream
    }

    func notify(_ key: String) {
        continuations[key]?.values.forEach { $0.yield(()) }
    }

    private func remove(key: String, id: UUID) {
        continuations[key]?[id] = nil
    }
}
