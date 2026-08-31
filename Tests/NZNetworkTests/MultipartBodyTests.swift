import XCTest
@testable import NZNetwork

private struct TestPart: Part {
    let name: String
    let filename: String?
    let body: Data?
    let value: String?
    let mimeType: MIMEType?
}

private struct TestInterceptor: InterceptorProtocol {
    let baseURL = "api.example.com"
    let timeout: TimeInterval = 10
}

final class MultipartBodyTests: XCTestCase {

    private let interceptor = TestInterceptor()

    func testInMemoryBodyContainsBoundaryAndFieldValue() {
        let part = TestPart(name: "bio", filename: nil, body: nil, value: "hello", mimeType: nil)
        let data = interceptor.beforeInterceptionBodyCreatorFor(multiparts: [part], boundary: "BOUNDARY")
        let string = String(data: data, encoding: .utf8)!

        XCTAssertTrue(string.contains("--BOUNDARY"))
        XCTAssertTrue(string.contains("Content-Disposition: form-data; name=\"bio\""))
        XCTAssertTrue(string.contains("hello"))
        XCTAssertTrue(string.hasSuffix("--BOUNDARY--"))
    }

    func testInMemoryBodyIncludesFilenameAndMimeTypeForFileParts() {
        let part = TestPart(name: "avatar", filename: "avatar.jpg", body: Data([0x01, 0x02]), value: nil, mimeType: .image(subtype: .jpeg))
        let data = interceptor.beforeInterceptionBodyCreatorFor(multiparts: [part], boundary: "BOUNDARY")
        let string = String(data: data, encoding: .isoLatin1)!

        XCTAssertTrue(string.contains("filename=\"avatar.jpg\""))
        XCTAssertTrue(string.contains("Content-Type: image/jpeg"))
    }

    func testFileStreamedBodyMatchesInMemoryBody() throws {
        let parts: [Part] = [
            TestPart(name: "bio", filename: nil, body: nil, value: "hello", mimeType: nil),
            TestPart(name: "avatar", filename: "avatar.jpg", body: Data([0x01, 0x02, 0x03]), value: nil, mimeType: .image(subtype: .jpeg))
        ]

        let inMemory = interceptor.beforeInterceptionBodyCreatorFor(multiparts: parts, boundary: "BOUNDARY")
        let fileURL = interceptor.multipartBodyFileURL(multiparts: parts, boundary: "BOUNDARY")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let streamed = try Data(contentsOf: fileURL)
        XCTAssertEqual(streamed, inMemory)
    }

    func testFileStreamedBodyIsWrittenToATemporaryFile() {
        let part = TestPart(name: "bio", filename: nil, body: nil, value: "hello", mimeType: nil)
        let fileURL = interceptor.multipartBodyFileURL(multiparts: [part], boundary: "BOUNDARY")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(fileURL.path.hasPrefix(FileManager.default.temporaryDirectory.path))
    }
}
