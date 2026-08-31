import XCTest
@testable import NZNetwork

final class RetryPolicyTests: XCTestCase {

    func testNoneNeverRetries() {
        XCTAssertNil(RetryPolicy.none.delayBeforeRetrying(statusCode: 503, attempt: 1))
    }

    func testRetriesConfiguredStatusCodesUnderMaxAttempts() {
        let policy = RetryPolicy(maxAttempts: 3, retryableStatusCodes: [503])
        XCTAssertNotNil(policy.delayBeforeRetrying(statusCode: 503, attempt: 1))
        XCTAssertNotNil(policy.delayBeforeRetrying(statusCode: 503, attempt: 2))
    }

    func testDoesNotRetryAtOrAfterMaxAttempts() {
        let policy = RetryPolicy(maxAttempts: 2, retryableStatusCodes: [503])
        XCTAssertNil(policy.delayBeforeRetrying(statusCode: 503, attempt: 2))
        XCTAssertNil(policy.delayBeforeRetrying(statusCode: 503, attempt: 3))
    }

    func testDoesNotRetryNonRetryableStatusCode() {
        let policy = RetryPolicy(maxAttempts: 3, retryableStatusCodes: [503])
        XCTAssertNil(policy.delayBeforeRetrying(statusCode: 404, attempt: 1))
    }

    func testDefaultRetryableStatusCodes() {
        let policy = RetryPolicy(maxAttempts: 3)
        for code in [429, 500, 502, 503, 504] {
            XCTAssertNotNil(policy.delayBeforeRetrying(statusCode: code, attempt: 1), "expected \(code) to be retryable")
        }
        XCTAssertNil(policy.delayBeforeRetrying(statusCode: 400, attempt: 1))
    }

    func testDefaultBackoffIsExponential() {
        let policy = RetryPolicy(maxAttempts: 10)
        XCTAssertEqual(policy.backoff(1), 1)
        XCTAssertEqual(policy.backoff(2), 2)
        XCTAssertEqual(policy.backoff(3), 4)
    }

    func testCustomBackoffIsUsed() {
        let policy = RetryPolicy(maxAttempts: 10, backoff: { attempt in Double(attempt) * 0.5 })
        XCTAssertEqual(policy.delayBeforeRetrying(statusCode: 503, attempt: 1), 0.5)
        XCTAssertEqual(policy.delayBeforeRetrying(statusCode: 503, attempt: 2), 1.0)
    }
}
