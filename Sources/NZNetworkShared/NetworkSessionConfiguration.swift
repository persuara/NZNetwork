import Foundation

/// Session-level networking behavior shared by `Network` and `NZDownloader`.
///
/// Pass one to their initializers to opt into standard HTTP caching, restrict cellular/expensive
/// network usage, or make requests wait for connectivity instead of failing immediately.
public struct NetworkSessionConfiguration: @unchecked Sendable {

    /// The cache policy applied to every request unless overridden per-request.
    ///
    /// Defaults to `.reloadIgnoringLocalAndRemoteCacheData` (no caching), matching this
    /// framework's historical behavior. Pass `.useProtocolCachePolicy` to opt into standard
    /// HTTP caching semantics.
    public var cachePolicy: URLRequest.CachePolicy

    /// A custom `URLCache` to back the session. `nil` keeps the platform default (`URLCache.shared`).
    public var urlCache: URLCache?

    /// Whether requests may use the cellular network. Default `true`.
    public var allowsCellularAccess: Bool

    /// Whether requests may use an expensive network interface (e.g. a personal hotspot). Default `true`.
    public var allowsExpensiveNetworkAccess: Bool

    /// Whether requests may use a constrained network interface (e.g. Low Data Mode). Default `true`.
    public var allowsConstrainedNetworkAccess: Bool

    /// When `true`, tasks wait for connectivity to become available instead of failing immediately. Default `false`.
    public var waitsForConnectivity: Bool

    /// Custom `URLProtocol` subclasses to install on the session, ahead of the system defaults.
    /// `nil` (default) leaves the session's protocol handling untouched. Primarily useful for
    /// injecting a stub `URLProtocol` in tests.
    public var protocolClasses: [AnyClass]?

    public init(
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData,
        urlCache: URLCache? = nil,
        allowsCellularAccess: Bool = true,
        allowsExpensiveNetworkAccess: Bool = true,
        allowsConstrainedNetworkAccess: Bool = true,
        waitsForConnectivity: Bool = false,
        protocolClasses: [AnyClass]? = nil
    ) {
        self.cachePolicy = cachePolicy
        self.urlCache = urlCache
        self.allowsCellularAccess = allowsCellularAccess
        self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
        self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
        self.waitsForConnectivity = waitsForConnectivity
        self.protocolClasses = protocolClasses
    }

    /// The default configuration, preserving this framework's historical behavior (no caching).
    public static let `default` = NetworkSessionConfiguration()

    /// Applies these settings onto a `URLSessionConfiguration`.
    public func apply(to configuration: URLSessionConfiguration) {
        configuration.requestCachePolicy = cachePolicy
        if let urlCache {
            configuration.urlCache = urlCache
        }
        configuration.allowsCellularAccess = allowsCellularAccess
        configuration.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
        configuration.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
        configuration.waitsForConnectivity = waitsForConnectivity
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
    }
}
