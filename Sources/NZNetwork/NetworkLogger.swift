import Foundation

/// A hook for observing every request/response that passes through a `Network` instance,
/// independent of `InterceptorProtocol` — useful for logging, analytics, or debugging without
/// entangling that logic with request/response transformation.
public protocol NetworkLogger {
    /// Called right before a request is sent (after interception).
    func log(request: InterceptorRequest)

    /// Called after a response is received (after interception), once per actual HTTP round
    /// trip — including once per retry attempt.
    func log(response: InterceptorResponse, data: Data)

    /// Called when a request fails with a transport-level error (not a non-2xx response).
    func log(error: Error, for request: InterceptorRequest)
}

/// A ready-to-use `NetworkLogger` that prints to the console.
public struct ConsoleNetworkLogger: NetworkLogger {

    /// How much detail to print.
    public enum Level {
        /// Method and URL only.
        case basic
        /// Method, URL, and headers.
        case headers
        /// Method, URL, headers, and body.
        case body
    }

    public var level: Level

    public init(level: Level = .basic) {
        self.level = level
    }

    public func log(request: InterceptorRequest) {
        print("➡️ \(request.method.rawValue) \(request.url.absoluteString)")
        guard level == .headers || level == .body else { return }
        request.headers.forEach { print("   \($0.key): \($0.value)") }
    }

    public func log(response: InterceptorResponse, data: Data) {
        print("⬅️ \(response.statusCode) \(response.request.method.rawValue) \(response.request.url.absoluteString)")
        guard level == .body else { return }
        if let body = String(data: data, encoding: .utf8), !body.isEmpty {
            print("   \(body)")
        }
    }

    public func log(error: Error, for request: InterceptorRequest) {
        print("❌ \(request.method.rawValue) \(request.url.absoluteString) — \(error.localizedDescription)")
    }
}
