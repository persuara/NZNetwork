import XCTest
@testable import NZNetworkShared

final class DataAppendTests: XCTestCase {

    func testAppendsUTF8StringBytes() {
        var data = Data()
        data.append("hello")
        XCTAssertEqual(data, Data("hello".utf8))
    }

    func testAppendingMultipleStringsConcatenates() {
        var data = Data()
        data.append("foo")
        data.append("bar")
        XCTAssertEqual(String(data: data, encoding: .utf8), "foobar")
    }
}
