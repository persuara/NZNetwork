import XCTest
import NZNetworkShared
@testable import NZNetwork

private struct StubInterceptor: InterceptorProtocol {
    let baseURL = "api.example.com"
    let timeout: TimeInterval = 5
}

@available(iOS 15.0, *)
final class NetworkStreamingTests: XCTestCase {

    private var network: Network!

    override func setUp() {
        super.setUp()
        StubURLProtocol.handler = nil
        StubURLProtocol.recordedRequests = []
        network = Network(
            interceptor: StubInterceptor(),
            sessionConfiguration: NetworkSessionConfiguration(protocolClasses: [StubURLProtocol.self])
        )
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        StubURLProtocol.recordedRequests = []
        network = nil
        super.tearDown()
    }

    func testStreamYieldsFullBodyContent() async throws {
        let payload = Data("hello streaming world".utf8)
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 200, data: payload)) }

        var received = Data()
        for try await chunk in network.stream(path: Path(route: "/events", queryItems: nil)) {
            received.append(chunk)
        }

        XCTAssertEqual(received, payload)
    }

    func testStreamRespectsChunkSize() async throws {
        let payload = Data(repeating: 0x41, count: 100)
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 200, data: payload)) }

        var chunkCount = 0
        var received = Data()
        for try await chunk in network.stream(path: Path(route: "/events", queryItems: nil), chunkSize: 10) {
            chunkCount += 1
            received.append(chunk)
        }

        XCTAssertEqual(received, payload)
        XCTAssertGreaterThanOrEqual(chunkCount, 10)
    }

    func testStreamThrowsRemoteErrorForNon2xx() async throws {
        let errorPayload = Data(#"{"error":"nope"}"#.utf8)
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 500, data: errorPayload)) }

        do {
            for try await _ in network.stream(path: Path(route: "/events", queryItems: nil)) {
                XCTFail("expected no chunks before the error")
            }
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error.remoteErrorData, errorPayload)
        }
    }

    func testStreamLinesYieldsEachLine() async throws {
        let payload = Data("line one\nline two\nline three".utf8)
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 200, data: payload)) }

        var lines: [String] = []
        for try await line in network.streamLines(path: Path(route: "/events", queryItems: nil)) {
            lines.append(line)
        }

        XCTAssertEqual(lines, ["line one", "line two", "line three"])
    }

    func testStreamSendsGETAndInterceptorHeaders() async throws {
        struct AuthInterceptor: InterceptorProtocol {
            let baseURL = "api.example.com"
            let timeout: TimeInterval = 5
            func intercept(request: InterceptorRequest) async -> InterceptorRequest {
                var request = request
                request.headers["Authorization"] = "Bearer token123"
                return request
            }
        }

        StubURLProtocol.handler = { _ in .success(.init(statusCode: 200, data: Data("ok".utf8))) }
        let authedNetwork = Network(
            interceptor: AuthInterceptor(),
            sessionConfiguration: NetworkSessionConfiguration(protocolClasses: [StubURLProtocol.self])
        )

        for try await _ in authedNetwork.stream(path: Path(route: "/events", queryItems: nil)) {}

        let request = StubURLProtocol.recordedRequests.first
        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer token123")
    }
}
