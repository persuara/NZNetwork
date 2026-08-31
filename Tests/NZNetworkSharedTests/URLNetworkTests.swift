import XCTest
@testable import NZNetworkShared

final class URLNetworkTests: XCTestCase {

    func testBuildsHTTPSURLFromBaseEndpointAndRoute() {
        let url = URL(baseEndPoint: "api.example.com", route: "/users", queryItems: nil)
        XCTAssertEqual(url.absoluteString, "https://api.example.com/users")
    }

    func testAddsMissingLeadingSlashOnRoute() {
        let url = URL(baseEndPoint: "api.example.com", route: "users", queryItems: nil)
        XCTAssertEqual(url.absoluteString, "https://api.example.com/users")
    }

    func testDoesNotDuplicateSlashWhenBaseURLAlreadyEndsWithOne() {
        let url = URL(baseEndPoint: "api.example.com/", route: "/users", queryItems: nil)
        XCTAssertEqual(url.absoluteString, "https://api.example.com/users")
    }

    func testAppendsQueryItems() {
        let url = URL(baseEndPoint: "api.example.com", route: "/users", queryItems: [URLQueryItem(name: "page", value: "1")])
        XCTAssertEqual(url.absoluteString, "https://api.example.com/users?page=1")
    }

    func testDoesNotProduceDoubleSlashWhenRouteHasLeadingSlash() {
        // Regression test: baseEndPoint's trailing "/" plus route's leading "/" used to produce "//".
        let url = URL(baseEndPoint: "api.example.com", route: "/users", queryItems: nil)
        XCTAssertEqual(url.absoluteString, "https://api.example.com/users")
    }

    func testRouteStartingWithHTTPIsUsedAsIs() {
        let url = URL(baseEndPoint: "api.example.com", route: "https://other.example.com/full/path", queryItems: nil)
        XCTAssertEqual(url.absoluteString, "https://other.example.com/full/path")
    }
}
