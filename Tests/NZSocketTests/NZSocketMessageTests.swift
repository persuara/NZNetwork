import XCTest
@testable import NZSocket

final class NZSocketMessageTests: XCTestCase {

    func testStringMessageBridgesToURLSessionMessage() {
        let message = NZSocketMessage.string("hello")
        guard case .string(let value) = message.asURLSessionMessage else {
            return XCTFail("expected .string")
        }
        XCTAssertEqual(value, "hello")
    }

    func testDataMessageBridgesToURLSessionMessage() {
        let payload = Data([0x01, 0x02])
        let message = NZSocketMessage.data(payload)
        guard case .data(let value) = message.asURLSessionMessage else {
            return XCTFail("expected .data")
        }
        XCTAssertEqual(value, payload)
    }

    func testURLSessionStringMessageBridgesBack() {
        let message = URLSessionWebSocketTask.Message.string("hi").asNZSocketMessage
        guard case .string(let value) = message else {
            return XCTFail("expected .string")
        }
        XCTAssertEqual(value, "hi")
    }

    func testURLSessionDataMessageBridgesBack() {
        let payload = Data([0x03, 0x04])
        let message = URLSessionWebSocketTask.Message.data(payload).asNZSocketMessage
        guard case .data(let value) = message else {
            return XCTFail("expected .data")
        }
        XCTAssertEqual(value, payload)
    }

    func testPathDefaultsToNoQueryItems() {
        let path = Path(route: "/chat")
        XCTAssertEqual(path.route, "/chat")
        XCTAssertNil(path.queryItems)
    }
}
