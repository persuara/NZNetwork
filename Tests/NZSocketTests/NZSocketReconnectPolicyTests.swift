import XCTest
@testable import NZSocket

final class NZSocketReconnectPolicyTests: XCTestCase {

    func testNoneNeverReconnects() {
        XCTAssertNil(NZSocketReconnectPolicy.none.delayBeforeReconnecting(attempt: 1))
    }

    func testReconnectsUnderMaxAttempts() {
        let policy = NZSocketReconnectPolicy(maxAttempts: 3)
        XCTAssertNotNil(policy.delayBeforeReconnecting(attempt: 1))
        XCTAssertNotNil(policy.delayBeforeReconnecting(attempt: 3))
    }

    func testDoesNotReconnectAfterMaxAttempts() {
        let policy = NZSocketReconnectPolicy(maxAttempts: 3)
        XCTAssertNil(policy.delayBeforeReconnecting(attempt: 4))
    }

    func testDefaultBackoffIsExponentialCappedAt30() {
        let policy = NZSocketReconnectPolicy(maxAttempts: 10)
        XCTAssertEqual(policy.backoff(1), 1)
        XCTAssertEqual(policy.backoff(2), 2)
        XCTAssertEqual(policy.backoff(3), 4)
        XCTAssertEqual(policy.backoff(10), 30)
    }

    func testCustomBackoffIsUsed() {
        let policy = NZSocketReconnectPolicy(maxAttempts: 5, backoff: { attempt in Double(attempt) * 2 })
        XCTAssertEqual(policy.delayBeforeReconnecting(attempt: 1), 2)
        XCTAssertEqual(policy.delayBeforeReconnecting(attempt: 2), 4)
    }
}
