import XCTest
import NZNetworkShared
@testable import NZNetwork

private struct StubInterceptor: InterceptorProtocol {
    let baseURL = "api.example.com"
    let timeout: TimeInterval = 5
}

final class NetworkIntegrationTests: XCTestCase {

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

    func testGetSuccessReturnsResponseData() async {
        let payload = Data(#"{"id":1}"#.utf8)
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 200, data: payload)) }

        let result = await network.get(path: Path(route: "/users/1", queryItems: nil))

        guard case .success(let data) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(data, payload)
    }

    func testNon2xxStatusCodeReturnsRemoteError() async {
        let payload = Data(#"{"error":"not found"}"#.utf8)
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 404, data: payload)) }

        let result = await network.get(path: Path(route: "/users/999", queryItems: nil))

        guard case .remoteError(let data) = result else {
            return XCTFail("expected .remoteError, got \(result)")
        }
        XCTAssertEqual(data, payload)
    }

    func testTransportFailureReturnsLocalError() async {
        StubURLProtocol.handler = { _ in .failure(URLError(.notConnectedToInternet)) }

        let result = await network.get(path: Path(route: "/users/1", queryItems: nil))

        guard case .localError = result else {
            return XCTFail("expected .localError, got \(result)")
        }
    }

    func testThrowableAPIThrowsRemoteErrorForNon2xx() async {
        let payload = Data(#"{"error":"nope"}"#.utf8)
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 500, data: payload)) }

        do {
            _ = try await network.getThrowable(path: Path(route: "/users/1", queryItems: nil))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error.remoteErrorData, payload)
        }
    }

    func testPostEncodesJSONPayload() async {
        struct NewUser: Encodable { let name: String }
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 201)) }

        _ = await network.post(path: Path(route: "/users", queryItems: nil), payload: NewUser(name: "Ada"))

        let request = StubURLProtocol.recordedRequests.first
        XCTAssertEqual(request?.httpMethod, "POST")
        let sentBody = request.flatMap { $0.httpBodyStream == nil ? $0.httpBody : nil }
        if let sentBody {
            XCTAssertEqual(String(data: sentBody, encoding: .utf8), #"{"name":"Ada"}"#)
        }
    }

    func testRetryPolicyRetriesOnRetryableStatusThenSucceeds() async {
        var attempt = 0
        StubURLProtocol.handler = { _ in
            attempt += 1
            if attempt == 1 {
                return .success(.init(statusCode: 503))
            }
            return .success(.init(statusCode: 200, data: Data("ok".utf8)))
        }

        let retryingNetwork = Network(
            interceptor: StubInterceptor(),
            retryPolicy: RetryPolicy(maxAttempts: 3, backoff: { _ in 0 }),
            sessionConfiguration: NetworkSessionConfiguration(protocolClasses: [StubURLProtocol.self])
        )

        let result = await retryingNetwork.get(path: Path(route: "/flaky", queryItems: nil))

        guard case .success(let data) = result else {
            return XCTFail("expected eventual .success, got \(result)")
        }
        XCTAssertEqual(data, Data("ok".utf8))
        XCTAssertEqual(attempt, 2)
        XCTAssertEqual(StubURLProtocol.recordedRequests.count, 2)
    }

    func testWithoutRetryPolicyDoesNotRetry() async {
        var attempt = 0
        StubURLProtocol.handler = { _ in
            attempt += 1
            return .success(.init(statusCode: 503))
        }

        let result = await network.get(path: Path(route: "/flaky", queryItems: nil))

        guard case .remoteError = result else {
            return XCTFail("expected .remoteError, got \(result)")
        }
        XCTAssertEqual(attempt, 1)
    }

    func testCancellingTaskSurfacesAsCancelledResult() async {
        StubURLProtocol.handler = { _ in
            Thread.sleep(forTimeInterval: 0.3)
            return .success(.init(statusCode: 200))
        }

        let task = Task {
            await network.get(path: Path(route: "/slow", queryItems: nil))
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        let result = await task.value
        guard case .cancelled = result else {
            return XCTFail("expected .cancelled, got \(result)")
        }
    }

    func testCancellableHandleCancelsInFlightRequest() async {
        StubURLProtocol.handler = { _ in
            Thread.sleep(forTimeInterval: 0.3)
            return .success(.init(statusCode: 200))
        }

        let handle = network.getCancellable(path: Path(route: "/slow", queryItems: nil))
        try? await Task.sleep(nanoseconds: 50_000_000)
        handle.cancel()

        let result = await handle.result
        guard case .cancelled = result else {
            return XCTFail("expected .cancelled, got \(result)")
        }
    }

    func testInterceptorHeaderIsSentOnRequest() async {
        struct AuthInterceptor: InterceptorProtocol {
            let baseURL = "api.example.com"
            let timeout: TimeInterval = 5
            func intercept(request: InterceptorRequest) async -> InterceptorRequest {
                var request = request
                request.headers["Authorization"] = "Bearer token123"
                return request
            }
        }

        StubURLProtocol.handler = { _ in .success(.init(statusCode: 200)) }
        let authedNetwork = Network(
            interceptor: AuthInterceptor(),
            sessionConfiguration: NetworkSessionConfiguration(protocolClasses: [StubURLProtocol.self])
        )

        _ = await authedNetwork.get(path: Path(route: "/me", queryItems: nil))

        XCTAssertEqual(StubURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer token123")
    }

    func testPerRequestTimeoutOverridesInterceptorDefault() async {
        StubURLProtocol.handler = { _ in .success(.init(statusCode: 200)) }

        _ = await network.get(path: Path(route: "/users", queryItems: nil, timeout: 42))

        XCTAssertEqual(StubURLProtocol.recordedRequests.first?.timeoutInterval, 42)
    }
}
