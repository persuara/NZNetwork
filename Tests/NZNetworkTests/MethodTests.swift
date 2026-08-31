import XCTest
@testable import NZNetwork

final class MethodTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(Network.Method.get.rawValue, "GET")
        XCTAssertEqual(Network.Method.post(body: Data()).rawValue, "POST")
        XCTAssertEqual(Network.Method.put(body: Data()).rawValue, "PUT")
        XCTAssertEqual(Network.Method.delete(body: nil).rawValue, "DELETE")
        XCTAssertEqual(Network.Method.patch(body: Data()).rawValue, "PATCH")
        XCTAssertEqual(Network.Method.head.rawValue, "HEAD")
        XCTAssertEqual(Network.Method.options.rawValue, "OPTIONS")
    }

    func testRequestBodyExtraction() {
        let body = Data("payload".utf8)
        XCTAssertNil(Network.Method.get.requestBody as? Data)
        XCTAssertEqual(Network.Method.post(body: body).requestBody as? Data, body)
        XCTAssertEqual(Network.Method.put(body: body).requestBody as? Data, body)
        XCTAssertEqual(Network.Method.patch(body: body).requestBody as? Data, body)
        XCTAssertNil(Network.Method.head.requestBody)
        XCTAssertNil(Network.Method.options.requestBody)
    }
}
