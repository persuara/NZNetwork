import Foundation

/// Configures automatic retries for requests that fail with a retryable HTTP status code.
///
/// Retries are only applied to non-2xx responses that come back from the server (e.g. `429`,
/// `503`) — transport-level failures (no connection, DNS failure, etc.) and cancellations are
/// never retried automatically.
public struct RetryPolicy {

    /// The maximum number of attempts for a single request, including the first one.
    /// `1` (the default via `.none`) disables retries entirely.
    public var maxAttempts: Int

    /// The set of HTTP status codes that should trigger a retry.
    public var retryableStatusCodes: Set<Int>

    /// Computes the delay, in seconds, to wait before the given attempt.
    ///
    /// - Parameter attempt: The attempt number that just failed (`1` for the first attempt).
    public var backoff: (_ attempt: Int) -> TimeInterval

    /// Creates a retry policy.
    ///
    /// - Parameters:
    ///   - maxAttempts: The maximum number of attempts for a single request, including the first one.
    ///   - retryableStatusCodes: The set of HTTP status codes that should trigger a retry (default: `429`, `500`, `502`, `503`, `504`).
    ///   - backoff: Computes the delay, in seconds, before retrying attempt `attempt`. Defaults to exponential backoff (1s, 2s, 4s, …).
    public init(
        maxAttempts: Int = 3,
        retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504],
        backoff: @escaping (_ attempt: Int) -> TimeInterval = { attempt in pow(2.0, Double(attempt - 1)) }
    ) {
        self.maxAttempts = maxAttempts
        self.retryableStatusCodes = retryableStatusCodes
        self.backoff = backoff
    }

    /// No automatic retries. This is the default for `Network` when no policy is supplied.
    public static let none = RetryPolicy(maxAttempts: 1)

    /// Returns the delay before retrying, or `nil` if this status code/attempt shouldn't be retried.
    internal func delayBeforeRetrying(statusCode: Int, attempt: Int) -> TimeInterval? {
        guard attempt < maxAttempts, retryableStatusCodes.contains(statusCode) else {
            return nil
        }
        return backoff(attempt)
    }
}
