import Foundation
import NZNetworkShared

/// A protocol defining the contract for intercepting and modifying network requests and responses.
public protocol InterceptorProtocol {
    /// The base URL for network requests.
    var baseURL: String { get }
    
    /// The timeout interval for network requests.
    var timeout: TimeInterval { get }
    
    /// Intercepts and modifies an outgoing network request.
    ///
    /// - Parameter request: The original `InterceptorRequest` to be intercepted.
    /// - Returns: The modified `InterceptorRequest` after interception.
    func intercept(request: InterceptorRequest) async -> InterceptorRequest
    
    /// Intercepts and processes an incoming network response.
    ///
    /// - Parameter response: The original `InterceptorResponse` to be intercepted.
    /// - Returns: The modified `InterceptorResponse` after interception.
    func intercept(response: InterceptorResponse) async -> InterceptorResponse
    
    /// Creates the body data for a multipart form request before interception.
    ///
    /// - Parameters:
    ///   - multiparts: An array of `Part` objects representing the form data parts.
    ///   - boundary: The unique boundary string used to separate parts in the request.
    ///   - mimeType: The MIME type of the multipart data.
    /// - Returns: A `Data` object representing the properly formatted multipart form request body.
    func beforeInterceptionBodyCreatorFor(multiparts: [Part], boundary: String) -> Data
    
    /// Sets up initial headers for a multipart request, adding a `Content-Type` if a boundary is provided.
    ///
    /// - Parameters:
    ///   - headers: A dictionary of existing HTTP headers.
    ///   - boundary: An optional boundary string for multipart form data.
    /// - Returns: A modified dictionary containing the necessary headers for a multipart request.
    func setupingInitialHeaders(_ headers: [String: String], boundary: String?) -> [String: String]
    
    // MARK: - Throwable APIs
    /// Intercepts throwable and modifies an outgoing network request.
    ///
    /// - Parameter request: The original `InterceptorRequest` to be intercepted.
    /// - Returns: The modified `InterceptorRequest` after interception.
    /// This api added to provided error handling for interception proccesses.
    func interceptThrowable(request: InterceptorRequest) async throws -> InterceptorRequest
    
    /// Intercepts throwable and modifies an incoming network response.
    ///
    /// - Parameter request: The original `InterceptorResponse` to be intercepted.
    /// - Returns: The modified `InterceptorResponse` after interception.
    /// This api added to provided error handling for interception proccesses.
    func interceptThrowable(response: InterceptorResponse) async throws -> InterceptorResponse

    /// Handles an authentication challenge presented by the underlying `URLSession` — e.g. for
    /// SSL/certificate pinning (`NSURLAuthenticationMethodServerTrust`), client certificate
    /// authentication, or Basic/NTLM credentials.
    ///
    /// - Parameter challenge: The challenge presented by the server.
    /// - Returns: The disposition to use, and a credential when the disposition requires one.
    func handle(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)
}

// MARK: - Default Implementation

public extension InterceptorProtocol {
    /// Default implementation of request interception, which returns the original request unchanged.
    ///
    /// - Parameter request: The original `InterceptorRequest` to be intercepted.
    /// - Returns: The original `InterceptorRequest`.
    func intercept(request: InterceptorRequest) async -> InterceptorRequest { request }
    
    /// Default implementation of response interception, which returns the original response unchanged.
    ///
    /// - Parameter response: The original `InterceptorResponse` to be intercepted.
    /// - Returns: The original `InterceptorResponse`.
    func intercept(response: InterceptorResponse) async -> InterceptorResponse { response }
    
    /// Default Implementaion of the body data for a multipart form request before interception.
    ///
    ///  - Parameters:
    ///     - mulriparts: An array containg the data parts.
    ///     - boundary: A UUID String representing the boundary.
    ///     - mimeType: The MIMEType of the data file.
    /// -   Returns: A `Data` object representing the properly formatted multipart form request body.
    func beforeInterceptionBodyCreatorFor(multiparts: [Part], boundary: String) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)"
        
        multiparts.forEach { aPart in
            body.append(boundaryPrefix)
            body.append("\r\n")
            if let filename = aPart.filename {
                body.append("Content-Disposition: form-data; name=\"\(aPart.name)\"; filename=\"\(filename)\"\r\n")
                if let mimeType = aPart.mimeType {
                    body.append("Content-Type: \(mimeType.mimeType ?? "")")
                }
            } else {
                let mimeType = aPart.mimeType ?? .text(subType: .plain(charset: .utf8))
                body.append("Content-Disposition: form-data; name=\"\(aPart.name)\"\r\n")
                body.append("Content-Type: \(mimeType.mimeType ?? "")")
            }
            
            body.append("\r\n")
            body.append("\r\n")
            
            if let value = aPart.value {
                body.append(value)
            }
            
            if let data = aPart.body {
                body.append(data)
            }
            
            body.append("\r\n")
        }
        
        body.append(boundaryPrefix.appending("--"))
        
        return body
    }
    
    func setupingInitialHeaders(_ headers: [String: String], boundary: String?) -> [String: String] {
        var headers = headers
        if let boundary {
            headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        }
        return headers
    }
    
    /// Default implementation of request interception, which returns the original request unchanged.
    ///
    /// - Parameter request: The original `InterceptorRequest` to be intercepted.
    /// - Returns: The original `InterceptorRequest`.
    func interceptThrowable(request: InterceptorRequest) async throws -> InterceptorRequest {
        request
    }
    
    /// Default implementation of response interception, which returns the original response unchanged.
    ///
    /// - Parameter response: The original `InterceptorResponse` to be intercepted.
    /// - Returns: The original `InterceptorResponse`.
    func interceptThrowable(response: InterceptorResponse) async throws -> InterceptorResponse {
        response
    }

    /// Default implementation of challenge handling, which performs the system's default handling
    /// (equivalent to not implementing a challenge handler at all).
    func handle(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
}
