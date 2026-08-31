import XCTest
@testable import NZNetwork

final class ErrorTests: XCTestCase {

    func testRemoteErrorDataExtraction() {
        let data = Data("error body".utf8)
        let error: Error = NetworkError.remoteError(data)
        XCTAssertEqual(error.remoteErrorData, data)
        XCTAssertNil(error.localError)
    }

    func testLocalErrorExtraction() {
        let underlying = NSError(domain: "test", code: 1)
        let error: Error = NetworkError.localError(underlying)
        XCTAssertEqual((error.localError as NSError?), underlying)
        XCTAssertNil(error.remoteErrorData)
    }

    func testNonNetworkErrorHasNoExtractedPayload() {
        let error: Error = NSError(domain: "other", code: 2)
        XCTAssertNil(error.remoteErrorData)
        XCTAssertNil(error.localError)
    }

    func testCancellationErrorIsRecognizedAsCancellation() {
        let error: Error = CancellationError()
        XCTAssertTrue(error.isCancellationError)
    }

    func testURLErrorCancelledIsRecognizedAsCancellation() {
        let error: Error = URLError(.cancelled)
        XCTAssertTrue(error.isCancellationError)
    }

    func testOtherURLErrorIsNotCancellation() {
        let error: Error = URLError(.timedOut)
        XCTAssertFalse(error.isCancellationError)
    }

    func testUnrelatedErrorIsNotCancellation() {
        let error: Error = NSError(domain: "test", code: 3)
        XCTAssertFalse(error.isCancellationError)
    }
}
