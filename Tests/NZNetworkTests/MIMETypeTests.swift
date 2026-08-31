import XCTest
@testable import NZNetwork

final class MIMETypeTests: XCTestCase {

    func testImageMIMEType() {
        XCTAssertEqual(MIMEType.image(subtype: .jpeg).mimeType, "image/jpeg")
        XCTAssertEqual(MIMEType.image(subtype: .png).mimeType, "image/png")
    }

    func testDocumentMIMEType() {
        XCTAssertEqual(MIMEType.document(subtype: .pdf).mimeType, "application/pdf")
    }

    func testOctetStreamMIMEType() {
        XCTAssertEqual(MIMEType.octetStream.mimeType, "application/octet-stream")
    }

    func testTextWithCharsetMIMEType() {
        XCTAssertEqual(MIMEType.text(subType: .plain(charset: .utf8)).mimeType, "text/plain; charset=utf-8")
    }

    func testCustomMIMEType() {
        XCTAssertEqual(MIMEType.custom(mimeType: "application/vnd.custom+json").mimeType, "application/vnd.custom+json")
    }

    func testSniffFileExtension() {
        XCTAssertEqual(MIMEType.sniff(fileExtension: "jpg").mimeType, "image/jpeg")
        XCTAssertEqual(MIMEType.sniff(fileExtension: "JPEG").mimeType, "image/jpeg")
        XCTAssertEqual(MIMEType.sniff(fileExtension: "pdf").mimeType, "application/pdf")
        XCTAssertEqual(MIMEType.sniff(fileExtension: "unknown-extension").mimeType, "application/octet-stream")
    }

    func testValidCustomMIMETypeInitializer() {
        let mimeType = MIMEType(mimeType: "application/json")
        XCTAssertEqual(mimeType?.mimeType, "application/json")
    }
}
