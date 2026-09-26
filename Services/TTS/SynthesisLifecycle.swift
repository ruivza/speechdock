import Foundation

/// Rejects results from cancelled or superseded synthesis operations.
@MainActor
final class SynthesisLifecycle {
    private(set) var generation = UUID()
    func invalidate() { generation = UUID() }
    func check(_ token: UUID) throws {
        try Task.checkCancellation()
        guard token == generation else { throw CancellationError() }
    }
}
