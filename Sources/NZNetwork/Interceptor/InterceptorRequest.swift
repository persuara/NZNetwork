import Foundation

/// A structure representing a network request to be intercepted and modified by an interceptor.
public struct InterceptorRequest {
    /// The URL for the network request.
    public var url: URL
    
    /// The HTTP method for the network request.
    public var method: Network.Method
    
    /// The headers to be included in the network request.
    public var headers: [String: String]
    
    /// The timeout interval for the network request.
    public var timeout: TimeInterval

    /// The cache policy for the network request.
    public var cachePolicy: URLRequest.CachePolicy

    /// An optional `Encodable` payload to be included in the request body.
    public var body: Encodable?

    /// An array of `Part` objects representing the form data parts.
    public var multiparts: [Part]?

    /// The URL of a temporary file to stream the request body from, if the body was built as a
    /// file rather than held in memory (e.g. large multipart uploads). When set, this takes
    /// precedence over any body carried by `method`'s associated `Data`.
    public var bodyFileURL: URL?

    /// Creates a new `InterceptorRequest` instance.
    ///
    /// - Parameters:
    ///   - url: The URL for the network request.
    ///   - method: The HTTP method for the network request.
    ///   - headers: The headers to be included in the network request.
    ///   - timeout: The timeout interval for the network request.
    ///   - cachePolicy: The cache policy for the network request.
    ///   - body: An optional `Encodable` payload to be included in the request body.
    ///   - multiparts: An optional array of `Part` objects representing the form data parts.
    ///   - bodyFileURL: The URL of a temporary file to stream the request body from, if any.
    public init(url: URL, method: Network.Method, headers: [String : String], timeout: TimeInterval, cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData, body: Encodable? = nil, multiparts: [Part]?, bodyFileURL: URL? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.timeout = timeout
        self.cachePolicy = cachePolicy
        self.body = body
        self.multiparts = multiparts
        self.bodyFileURL = bodyFileURL
    }
}

