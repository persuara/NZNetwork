import Foundation
import NZNetworkShared

/// A message sent or received over a WebSocket connection.
public enum NZSocketMessage: Sendable {
    case string(String)
    case data(Data)
}

/// Errors specific to `NZSocket` operations.
public enum NZSocketError: Error, Sendable {
    /// A `send`/`sendPing` call was made before `connect(to:protocols:)` was called, or after the connection closed.
    case notConnected
    /// A JSON-encoded value could not be represented as a UTF-8 string message.
    case encodingFailed
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

    /// Handles an authentication challenge presented by the underlying `URLSession` — e.g. for
    /// SSL/certificate pinning, client certificate authentication, or Basic/NTLM credentials.
    ///
    /// - Parameter challenge: The challenge presented by the server.
    /// - Returns: The disposition to use, and a credential when the disposition requires one.
    func socket(_ socket: NZSocketProtocol, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)

    /// Tells the delegate that the socket will attempt to reconnect after the connection dropped
    /// unexpectedly (only fires when a `reconnectPolicy` other than `.none` is in effect).
    ///
    /// - Parameters:
    ///   - attempt: The 1-based attempt number about to be made.
    ///   - delay: How long the socket will wait before attempting to reconnect.
    func socket(_ socket: NZSocketProtocol, willReconnectAttempt attempt: Int, after delay: TimeInterval)
}

public extension NZSocketDelegate {
    func socket(_ socket: NZSocketProtocol, didConnectWithProtocol protocol: String?) {}
    func socket(_ socket: NZSocketProtocol, didDisconnectWithCode code: URLSessionWebSocketTask.CloseCode, reason: Data?) {}
    func socket(_ socket: NZSocketProtocol, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
    func socket(_ socket: NZSocketProtocol, willReconnectAttempt attempt: Int, after delay: TimeInterval) {}
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
public final class NZSocket: NSObject, @unchecked Sendable {

    /// The delegate notified about connect/disconnect lifecycle events.
    weak public var delegate: NZSocketDelegate?

    /// The base URL used for constructing the connection URL.
    internal let baseURL: String

    /// The timeout interval used while establishing the connection.
    internal let timeout: TimeInterval

    /// Every field below is mutated both from whichever thread calls `connect`/`send`/`disconnect`,
    /// and from the `URLSession`'s own delegate queue — lock-protected so that's actually safe,
    /// rather than merely not-flagged by the Sendable checker. `internal` (not `private`) so
    /// `NZSocket+Public.swift` can perform an atomic compound read-and-update for reconnect decisions.
    internal let connectionStateBox = Locked(ConnectionState())

    internal struct ConnectionState {
        var task: URLSessionWebSocketTask?
        var messageContinuation: AsyncThrowingStream<NZSocketMessage, Error>.Continuation?
        var isConnected = false
        var lastPath: Path?
        var lastProtocols: [String] = []
        var isExplicitDisconnect = false
        var reconnectAttempt = 0
        var heartbeatTask: Task<Void, Never>?
    }

    internal var task: URLSessionWebSocketTask? {
        get { connectionStateBox.get().task }
        set { connectionStateBox.withLock { $0.task = newValue } }
    }

    internal var messageContinuation: AsyncThrowingStream<NZSocketMessage, Error>.Continuation? {
        get { connectionStateBox.get().messageContinuation }
        set { connectionStateBox.withLock { $0.messageContinuation = newValue } }
    }

    /// `true` while a WebSocket connection is open.
    public internal(set) var isConnected: Bool {
        get { connectionStateBox.get().isConnected }
        set { connectionStateBox.withLock { $0.isConnected = newValue } }
    }

    internal var lastPath: Path? {
        get { connectionStateBox.get().lastPath }
        set { connectionStateBox.withLock { $0.lastPath = newValue } }
    }

    internal var lastProtocols: [String] {
        get { connectionStateBox.get().lastProtocols }
        set { connectionStateBox.withLock { $0.lastProtocols = newValue } }
    }

    /// `true` once `disconnect()` has been called explicitly, suppressing auto-reconnect.
    internal var isExplicitDisconnect: Bool {
        get { connectionStateBox.get().isExplicitDisconnect }
        set { connectionStateBox.withLock { $0.isExplicitDisconnect = newValue } }
    }

    /// The number of reconnect attempts made since the last successful connection.
    internal var reconnectAttempt: Int {
        get { connectionStateBox.get().reconnectAttempt }
        set { connectionStateBox.withLock { $0.reconnectAttempt = newValue } }
    }

    /// The task periodically sending pings while connected, if `heartbeatInterval` is set.
    internal var heartbeatTask: Task<Void, Never>? {
        get { connectionStateBox.get().heartbeatTask }
        set { connectionStateBox.withLock { $0.heartbeatTask = newValue } }
    }

    /// Session-level behavior such as cellular access and connectivity waiting.
    internal let sessionConfiguration: NetworkSessionConfiguration

    /// Governs automatic reconnection after the connection drops unexpectedly.
    internal let reconnectPolicy: NZSocketReconnectPolicy

    /// How often to automatically send a ping while connected. `nil` (default) disables the
    /// built-in heartbeat scheduler.
    internal let heartbeatInterval: TimeInterval?

    /// Initializes a new instance of NZSocket.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL used for constructing the connection URL.
    ///   - timeout: The timeout interval used while establishing the connection (default is 10 seconds).
    ///   - sessionConfiguration: Session-level behavior such as cellular access and connectivity waiting.
    ///   - reconnectPolicy: Governs automatic reconnection after the connection drops unexpectedly.
    ///     Defaults to `.none` (no auto-reconnect).
    ///   - heartbeatInterval: How often to automatically send a ping while connected. `nil`
    ///     (default) disables the built-in heartbeat scheduler.
    public init(
        baseURL: String,
        timeout: TimeInterval = 10,
        sessionConfiguration: NetworkSessionConfiguration = NetworkSessionConfiguration(cachePolicy: .useProtocolCachePolicy),
        reconnectPolicy: NZSocketReconnectPolicy = .none,
        heartbeatInterval: TimeInterval? = nil
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.sessionConfiguration = sessionConfiguration
        self.reconnectPolicy = reconnectPolicy
        self.heartbeatInterval = heartbeatInterval
        super.init()
    }

    /// The URLSession used for the WebSocket task. Lazily created, lock-protected so concurrent
    /// first access from multiple threads can't race (a plain `lazy var` is not thread-safe).
    private let sessionBox = Locked<URLSession?>(nil)

    internal var session: URLSession {
        sessionBox.withLock { existing in
            if let existing { return existing }
            let configuration = URLSessionConfiguration.default
            sessionConfiguration.apply(to: configuration)
            let newSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            existing = newSession
            return newSession
        }
    }
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
