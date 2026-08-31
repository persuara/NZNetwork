import Foundation

/// Configures automatic reconnection when an `NZSocket` connection drops unexpectedly (i.e. not
/// from an explicit `disconnect()` call).
public struct NZSocketReconnectPolicy {

    /// The maximum number of reconnect attempts after an unexpected disconnect. `0` (the default
    /// via `.none`) disables auto-reconnect entirely.
    public var maxAttempts: Int

    /// Computes the delay, in seconds, to wait before the given reconnect attempt.
    public var backoff: (_ attempt: Int) -> TimeInterval

    /// Creates a reconnect policy.
    ///
    /// - Parameters:
    ///   - maxAttempts: The maximum number of reconnect attempts after an unexpected disconnect.
    ///   - backoff: Computes the delay, in seconds, before reconnect attempt `attempt` (`1`-based).
    ///     Defaults to exponential backoff capped at 30 seconds (1s, 2s, 4s, 8s, 16s, 30s, 30s, ...).
    public init(
        maxAttempts: Int = 5,
        backoff: @escaping (_ attempt: Int) -> TimeInterval = { attempt in min(30, pow(2.0, Double(attempt - 1))) }
    ) {
        self.maxAttempts = maxAttempts
        self.backoff = backoff
    }

    /// No automatic reconnection. This is the default for `NZSocket` when no policy is supplied.
    public static let none = NZSocketReconnectPolicy(maxAttempts: 0)

    /// Returns the delay before reconnecting, or `nil` if this attempt shouldn't be retried.
    internal func delayBeforeReconnecting(attempt: Int) -> TimeInterval? {
        guard attempt <= maxAttempts else { return nil }
        return backoff(attempt)
    }
}
