import XCTest
@testable import NZNetwork

final class FormBodyTests: XCTestCase {

    func testEncodesSingleField() {
        let body = FormBody([URLQueryItem(name: "grant_type", value: "password")])
        XCTAssertEqual(String(data: body.encoded, encoding: .utf8), "grant_type=password")
    }

    func testEncodesMultipleFieldsInOrder() {
        let body = FormBody([
            URLQueryItem(name: "grant_type", value: "password"),
            URLQueryItem(name: "username", value: "ada")
        ])
        XCTAssertEqual(String(data: body.encoded, encoding: .utf8), "grant_type=password&username=ada")
    }

    func testEncodesSpacesAsPlus() {
        let body = FormBody([URLQueryItem(name: "name", value: "ada lovelace")])
        XCTAssertEqual(String(data: body.encoded, encoding: .utf8), "name=ada+lovelace")
    }

    func testPercentEncodesReservedCharacters() {
        let body = FormBody([URLQueryItem(name: "q", value: "a&b=c")])
        XCTAssertEqual(String(data: body.encoded, encoding: .utf8), "q=a%26b%3Dc")
    }

    func testDictionaryInitializerProducesValidPairs() {
        let body = FormBody(["grant_type": "password"])
        XCTAssertEqual(String(data: body.encoded, encoding: .utf8), "grant_type=password")
    }

    func testMissingValueEncodesAsEmptyString() {
        let body = FormBody([URLQueryItem(name: "flag", value: nil)])
        XCTAssertEqual(String(data: body.encoded, encoding: .utf8), "flag=")
    }

    func testContentTypeConstant() {
        XCTAssertEqual(FormBody.contentType, "application/x-www-form-urlencoded; charset=utf-8")
    }
}
