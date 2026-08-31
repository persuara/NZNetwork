import Foundation
import Network

/// The kind of network interface currently carrying traffic.
public enum NZConnectionType: Sendable {
    case wifi
    case cellular
    case wiredEthernet
    case other
    case unavailable
}

/// A snapshot of the device's network reachability at a point in time.
public struct NZReachabilityStatus: Sendable {
    public let isConnected: Bool
    public let connectionType: NZConnectionType
    public let isExpensive: Bool
    public let isConstrained: Bool

    public init(isConnected: Bool, connectionType: NZConnectionType, isExpensive: Bool, isConstrained: Bool) {
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }

    internal init(path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else if path.status == .satisfied {
            connectionType = .other
        } else {
            connectionType = .unavailable
        }
    }
}

/// A protocol that defines methods for observing network reachability changes.
public protocol NZReachabilityDelegate: AnyObject {
    /// Tells the delegate that the network status changed.
    func reachability(_ reachability: NZReachabilityProtocol, didUpdateStatus status: NZReachabilityStatus)
}

/// A protocol that defines the interface for monitoring network reachability.
public protocol NZReachabilityProtocol: AnyObject {
    /// The delegate notified about status changes.
    var delegate: NZReachabilityDelegate? { get set }

    /// The most recently observed status. `nil` until `start()` has produced a first update.
    var currentStatus: NZReachabilityStatus? { get }

    /// `true` if the most recently observed status was connected. `true` by default before the
    /// first update arrives, so callers don't have to special-case startup as "offline".
    var isConnected: Bool { get }

    /// Begins monitoring. Safe to call again after `stop()`.
    func start()

    /// Stops monitoring and finishes any active `statusUpdates()` stream.
    func stop()

    /// A stream of every status change, starting from the next one observed after this call.
    func statusUpdates() -> AsyncStream<NZReachabilityStatus>
}

/// Monitors network reachability using `NWPathMonitor`, exposing the current online/offline
/// state and connection type via delegate callbacks and/or an `AsyncStream`.
public final class NZReachability: NZReachabilityProtocol, @unchecked Sendable {

    weak public var delegate: NZReachabilityDelegate?

    /// Lock-protected since it's written from `monitor`'s callback (delivered on `queue`) and
    /// read from whichever thread calls `currentStatus`/`isConnected`.
    private let lock = NSLock()
    private var _currentStatus: NZReachabilityStatus?
    private var continuation: AsyncStream<NZReachabilityStatus>.Continuation?

    public var currentStatus: NZReachabilityStatus? {
        lock.lock()
        defer { lock.unlock() }
        return _currentStatus
    }

    public var isConnected: Bool { currentStatus?.isConnected ?? true }

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    /// Creates a reachability monitor.
    ///
    /// - Parameters:
    ///   - requiredInterfaceType: Restricts monitoring to a single interface type (e.g. `.wifi`
    ///     to specifically track Wi-Fi reachability). `nil` (default) monitors all interfaces.
    ///   - queueLabel: The label for the internal dispatch queue `NWPathMonitor` delivers updates on.
    public init(requiredInterfaceType: NWInterface.InterfaceType? = nil, queueLabel: String = "NZReachability.monitor") {
        if let requiredInterfaceType {
            self.monitor = NWPathMonitor(requiredInterfaceType: requiredInterfaceType)
        } else {
            self.monitor = NWPathMonitor()
        }
        self.queue = DispatchQueue(label: queueLabel)
    }

    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let status = NZReachabilityStatus(path: path)
            self.lock.lock()
            self._currentStatus = status
            let continuation = self.continuation
            self.lock.unlock()
            self.delegate?.reachability(self, didUpdateStatus: status)
            continuation?.yield(status)
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
        lock.lock()
        let continuation = continuation
        lock.unlock()
        continuation?.finish()
    }

    public func statusUpdates() -> AsyncStream<NZReachabilityStatus> {
        AsyncStream { continuation in
            self.lock.lock()
            self.continuation = continuation
            self.lock.unlock()
        }
    }
}
