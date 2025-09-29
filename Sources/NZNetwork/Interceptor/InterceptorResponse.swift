import Foundation

/// A structure representing the response received from a network request, to be intercepted and modified by an interceptor.
public struct InterceptorResponse {
    /// An enumeration representing different possible outcomes of the intercepted response.
    public enum Result {
        /// The response indicates an error with the specified NSError.
        case error(error: NSError)
        
        /// The response contains data in the form of bytes.
        case response(data: Data)
        
        /// The response indicates the need to close the request or response connection.
        case close
        
        /// The response indicates the need to proceed with a modified request.
        case proceed(request: InterceptorRequest)
    }
    
    /// The original `InterceptorRequest` associated with the response.
    public var request: InterceptorRequest
    
    /// The localized message corresponding to the status code of the response.
    public var localizedMessageForStatusCode: String
    
    /// The HTTP status code received in the response.
    public var statusCode: Int
    
    /// The headers included in the response.
    public var headers: [String: String]
    
    /// The outcome of the intercepted response.
    public var result: Result
    
    /// Creates a new `InterceptorResponse` instance.
    ///
    /// - Parameters:
    ///   - request: The original `InterceptorRequest` associated with the response.
    ///   - localizedMessageForStatusCode: The localized message corresponding to the status code of the response.
    ///   - statusCode: The HTTP status code received in the response.
    ///   - headers: The headers included in the response.
    ///   - result: The outcome of the intercepted response, represented by the `Result` enumeration.
    public init(request: InterceptorRequest, localizedMessageForStatusCode: String, statusCode: Int, headers: [String : String], result: Result) {
        self.request = request
        self.localizedMessageForStatusCode = localizedMessageForStatusCode
        self.statusCode = statusCode
        self.headers = headers
        self.result = result
    }
}
