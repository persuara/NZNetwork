import XCTest
@testable import NZNetworkShared

final class URLRequestNetworkTests: XCTestCase {

    private let url = URL(string: "https://api.example.com/users")!

    func testAsGetSetsMethod() {
        var request = URLRequest(url: url)
        request.asGet()
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testAsPostSetsMethodAndBody() {
        var request = URLRequest(url: url)
        let body = Data("{}".utf8)
        request.asPost(body: body)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.httpBody, body)
    }

    func testAsPutSetsMethodAndBody() {
        var request = URLRequest(url: url)
        let body = Data("{}".utf8)
        request.asPut(body: body)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.httpBody, body)
    }

    func testAsDeleteWithoutBody() {
        var request = URLRequest(url: url)
        request.asDelete()
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertNil(request.httpBody)
    }

    func testAsDeleteWithBody() {
        var request = URLRequest(url: url)
        let body = Data("{}".utf8)
        request.asDelete(body: body)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.httpBody, body)
    }

    func testAsPatchSetsMethodAndBody() {
        var request = URLRequest(url: url)
        let body = Data("{}".utf8)
        request.asPatch(body: body)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.httpBody, body)
    }

    func testAsHeadSetsMethod() {
        var request = URLRequest(url: url)
        request.asHead()
        XCTAssertEqual(request.httpMethod, "HEAD")
    }

    func testAsOptionsSetsMethod() {
        var request = URLRequest(url: url)
        request.asOptions()
        XCTAssertEqual(request.httpMethod, "OPTIONS")
    }

    func testSetHeadersAppliesEveryEntry() {
        var request = URLRequest(url: url)
        request.setHeaders(["Authorization": "Bearer token", "X-Custom": "value"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "value")
    }
}
