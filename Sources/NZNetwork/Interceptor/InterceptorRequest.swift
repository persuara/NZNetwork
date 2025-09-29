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
    
    /// An optional `Encodable` payload to be included in the request body.
    public var body: Encodable?
    
    /// An array of `Part` objects representing the form data parts.
    public var multiparts: [Part]?
    
    /// Creates a new `InterceptorRequest` instance.
    ///
    /// - Parameters:
    ///   - url: The URL for the network request.
    ///   - method: The HTTP method for the network request.
    ///   - headers: The headers to be included in the network request.
    ///   - timeout: The timeout interval for the network request.
    ///   - body: An optional `Encodable` payload to be included in the request body.
    ///   - multiparts: An optional array of `Part` objects representing the form data parts.
    public init(url: URL, method: Network.Method, headers: [String : String], timeout: TimeInterval, body: Encodable? = nil, multiparts: [Part]?) {
        self.url = url
        self.method = method
        self.headers = headers
        self.timeout = timeout
        self.body = body
        self.multiparts = multiparts
    }
}

