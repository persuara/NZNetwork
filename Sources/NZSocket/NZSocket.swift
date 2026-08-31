import Foundation
import NZNetworkShared

/// A message sent or received over a WebSocket connection.
public enum NZSocketMessage {
    case string(String)
    case data(Data)
}

/// Errors specific to `NZSocket` operations.
public enum NZSocketError: Error {
    /// A `send`/`sendPing` call was made before `connect(to:protocols:)` was called, or after the connection closed.
    case notConnected
}

/// A protocol that defines the connection lifecycle events for `NZSocket`.
public protocol NZSocketDelegate: AnyObject {

    /// Tells the delegate that the socket connection was opened.
    ///
    /// - Parameters:
    ///   - socket: The socket instance.
    ///   - protocol: The `Sec-WebSocket-Protocol` value the server accepted, if any.
    func socket(_ socket: NZSocketProtocol, didConnectWithProtocol protocol: String?)

    /// Tells the delegate that the socket connection was closed.
    ///
    /// - Parameters:
    ///   - socket: The socket instance.
    ///   - code: The close code sent by the server (or `.invalid` on a local/transport failure).
    ///   - reason: An optional, server-supplied reason for the closure.
    func socket(_ socket: NZSocketProtocol, didDisconnectWithCode code: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

public extension NZSocketDelegate {
    func socket(_ socket: NZSocketProtocol, didConnectWithProtocol protocol: String?) {}
    func socket(_ socket: NZSocketProtocol, didDisconnectWithCode code: URLSessionWebSocketTask.CloseCode, reason: Data?) {}
}

/// A protocol that defines methods for opening, using, and closing a WebSocket connection.
public protocol NZSocketProtocol: AnyObject {

    /// The delegate notified about connect/disconnect lifecycle events.
    var delegate: NZSocketDelegate? { get set }

    /// `true` while a WebSocket connection is open.
    var isConnected: Bool { get }

    /// Opens a WebSocket connection to the specified path.
    ///
    /// - Parameters:
    ///   - path: The route (and optional query items) to connect to.
    ///   - protocols: Optional `Sec-WebSocket-Protocol` values to negotiate with the server.
    func connect(to path: Path, protocols: [String])

    /// Returns a stream that yields every message received on the current connection.
    ///
    /// The stream finishes when the connection is closed normally, or throws if the
    /// connection fails. Call this once per connection, before or after `connect(to:protocols:)`.
    func messages() -> AsyncThrowingStream<NZSocketMessage, Error>

    /// Sends a message over the open connection.
    ///
    /// - Throws: `NZSocketError.notConnected` if there is no open connection, or the underlying transport error.
    func send(_ message: NZSocketMessage) async throws

    /// Sends a ping frame, useful for keep-alive checks.
    ///
    /// - Throws: `NZSocketError.notConnected` if there is no open connection, or the underlying transport error.
    func sendPing() async throws

    /// Closes the connection.
    ///
    /// - Parameters:
    ///   - closeCode: The close code to send to the server.
    ///   - reason: An optional reason payload to send to the server.
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

/// A class that manages a single WebSocket connection, built on `URLSessionWebSocketTask`.
public final class NZSocket: NSObject {

    /// The delegate notified about connect/disconnect lifecycle events.
    weak public var delegate: NZSocketDelegate?

    /// The base URL used for constructing the connection URL.
    internal let baseURL: String

    /// The timeout interval used while establishing the connection.
    internal let timeout: TimeInterval

    /// The active WebSocket task, if connected.
    internal var task: URLSessionWebSocketTask?

    /// The continuation used to yield messages onto the `messages()` stream.
    internal var messageContinuation: AsyncThrowingStream<NZSocketMessage, Error>.Continuation?

    /// `true` while a WebSocket connection is open.
    public internal(set) var isConnected: Bool = false

    /// Initializes a new instance of NZSocket.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL used for constructing the connection URL.
    ///   - timeout: The timeout interval used while establishing the connection (default is 10 seconds).
    public init(baseURL: String, timeout: TimeInterval = 10) {
        self.baseURL = baseURL
        self.timeout = timeout
        super.init()
    }

    /// The URLSession used for the WebSocket task.
    internal lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
}

/// A struct representing a path for a WebSocket connection.
public struct Path {

    /// The route for the connection.
    ///
    /// Example: "/chat"
    public let route: String

    /// Optional query items to include in the connection URL.
    public let queryItems: [URLQueryItem]?

    public init(route: String, queryItems: [URLQueryItem]? = nil) {
        self.route = route
        self.queryItems = queryItems
    }
}
