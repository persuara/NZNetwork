import Foundation

/// A `URLProtocol` stub that lets tests hand back a canned response (or error) for every request,
/// without touching the network, and records every request it sees.
final class StubURLProtocol: URLProtocol {

    struct Response {
        let statusCode: Int
        let data: Data
        let headers: [String: String]

        init(statusCode: Int = 200, data: Data = Data(), headers: [String: String] = [:]) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
        }
    }

    /// Set before each test. Called once per request; return `.success` or `.failure`.
    static var handler: ((URLRequest) -> Result<Response, Error>)?

    /// Every request seen by the stub, in order. Reset this between tests.
    static var recordedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.recordedRequests.append(request)

        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        switch handler(request) {
        case .success(let response):
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
