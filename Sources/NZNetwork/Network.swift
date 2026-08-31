import Foundation
import NZNetworkShared

/// This protocol provides an interface to be used by any module that is making use of the Network module.
/// The use of this protocol is encouraged for all who are planning to use the Network module. so changes to the module in the future won't affect your code.
public protocol NetworkProtocol {

    /// Perform a GET request to the specified path.
    ///
    /// - Parameters:
    ///   - path: The API path for the GET request.
    ///   - callback: A closure that receives a `NetworkCallback` object containing
    ///               the response data, error information, and additional details.
    ///               The closure is invoked when the request completes.
    func get(path: Path) async -> NetworkResult

    /// Perform a POST request to the specified path with payload data.
    ///
    /// - Parameters:
    ///   - path: The API path for the POST request.
    ///   - payload: The payload data to include in the request body.
    ///   - callback: A closure that receives a `NetworkCallback` object containing
    ///               the response data, error information, and additional details.
    ///               The closure is invoked when the request completes.
    func post(path: Path, payload: Encodable) async -> NetworkResult
    
    func post(path: Path, multipart payload: Part...) async -> NetworkResult
    
    func post(path: Path, multiparts payload: [Part]) async -> NetworkResult

    /// Perform a PUT request to the specified path with payload data.
    ///
    /// - Parameters:
    ///   - path: The API path for the PUT request.
    ///   - payload: The payload data to include in the request body.
    ///   - callback: A closure that receives a `NetworkCallback` object containing
    ///               the response data, error information, and additional details.
    ///               The closure is invoked when the request completes.
    func put(path: Path, payload: Data) async -> NetworkResult
    
    func put(path: Path, multipart payload: Part...) async -> NetworkResult
    
    func put(path: Path, multiparts payload: [Part]) async -> NetworkResult

    /// Perform a PATCH request to the specified path with payload data.
    ///
    /// - Parameters:
    ///   - path: The API path for the PATCH request.
    ///   - payload: The payload data to include in the request body.
    ///   - callback: A closure that receives a `NetworkCallback` object containing
    ///               the response data, error information, and additional details.
    ///               The closure is invoked when the request completes.
    func patch(path: Path, payload: Encodable) async -> NetworkResult

    /// Perform a HEAD request to the specified path.
    ///
    /// - Parameter path: The API path for the HEAD request.
    func head(path: Path) async -> NetworkResult

    /// Perform an OPTIONS request to the specified path.
    ///
    /// - Parameter path: The API path for the OPTIONS request.
    func options(path: Path) async -> NetworkResult

    /// Perform a DELETE request to the specified path.
    ///
    /// - Parameters:
    ///   - path: The API path for the DELETE request.
    ///   - callback: A closure that receives a `NetworkCallback` object containing
    ///               the response data, error information, and additional details.
    ///               The closure is invoked when the request completes.
    func delete(path: Path) async -> NetworkResult
    
    func delete(path: Path, body: Data) async -> NetworkResult
    
    // MARK: - Throwable APIs
    /// Perform a GET request to the specified path.
    ///
    /// - Parameter path: The API path for the GET request.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error (e.g., non-200 status codes), local error, or if it is cancelled.
    func getThrowable(path: Path) async throws -> Data
    
    /// Perform a POST request to the specified path with payload data.
    ///
    /// - Parameters:
    ///   - path: The API path for the POST request.
    ///   - payload: The payload data to include in the request body.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error, local error, or if it is cancelled.
    func postThrowable(path: Path, payload: Encodable) async throws -> Data
    
    /// Perform a POST request to the specified path with multipart-form data.
    ///
    /// - Parameters:
    ///   - path: The API path for the POST request.
    ///   - multipart: An array of `Part` objects representing the form data parts.
    ///   - mimeType: MIMEType representation of the file data.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error, local error, or if it is cancelled.
    func postThrowable(path: Path, multipart payload: Part...) async throws -> Data
    
    /// Perform a PUT request to the specified path with payload data.
    ///
    /// - Parameters:
    ///   - path: The API path for the PUT request.
    ///   - payload: The payload data to include in the request body.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error, local error, or if it is cancelled.
    func putThrowable(path: Path, payload: Encodable) async throws -> Data
    
    /// Perform a PUT request to the specified path with multipart-form data.
    ///
    /// - Parameters:
    ///   - path: The API path for the PUT request.
    ///   - multipart: An array of `Part` objects representing the form data parts.
    ///   - mimeType: MIMEType representation of the file data.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error, local error, or if it is cancelled.
    func putThrowable(path: Path, multipart payload: Part...) async throws -> Data

    /// Perform a PATCH request to the specified path with payload data.
    ///
    /// - Parameters:
    ///   - path: The API path for the PATCH request.
    ///   - payload: The payload data to include in the request body.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error, local error, or if it is cancelled.
    func patchThrowable(path: Path, payload: Encodable) async throws -> Data

    /// Perform a HEAD request to the specified path.
    ///
    /// - Parameter path: The API path for the HEAD request.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error, local error, or if it is cancelled.
    func headThrowable(path: Path) async throws -> Data

    /// Perform an OPTIONS request to the specified path.
    ///
    /// - Parameter path: The API path for the OPTIONS request.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error, local error, or if it is cancelled.
    func optionsThrowable(path: Path) async throws -> Data

    /// Perform a DELETE request to the specified path.
    ///
    /// - Parameter path: The API path for the DELETE request.
    /// - Returns: The response data if the request is successful.
    /// - Throws: `NetworkError` if the request fails due to a remote error, local error, or if it is cancelled.
    func deleteThrowable(path: Path) async throws -> Data
}

public extension NetworkProtocol {
    
    func post(path: Path, payload: Encodable, isMultiPart: Bool) async -> NetworkResult {
        await post(path: path, payload: payload)
    }
    
    func put(path: Path, payload: Data, isMultiPart: Bool) async -> NetworkResult {
        await put(path: path, payload: payload)
    }
}

/// A struct representing a path for network requests.
public struct Path {
    
    /// The route for the network request.
    ///
    /// Example: "/category"
    public let route: String
    
    /// Optional query items to include in the request.
    ///
    /// Example: [URLQueryItem(name: "id", value: "1")]
    public let queryItems: [URLQueryItem]?

    /// Overrides the interceptor's default `timeout` for this specific request, if provided.
    public let timeout: TimeInterval?

    public init(route: String, queryItems: [URLQueryItem]?, timeout: TimeInterval? = nil) {
        self.route = route
        self.queryItems = queryItems
        self.timeout = timeout
    }
}


/// An enumeration representing different possible outcomes of a network request.
public enum NetworkResult {
    /// The network request returned a data object.
    /// This case indicates a successful network response with a successful status code (200...299).
    case success(response: Data)
    
    /// The network request returned a data object.
    /// This case indicates a network response without a successful status code.
    case remoteError(response: Data)
    
    /// An error occurred during the data task work.
    /// This case indicates an error that occurred while processing the network request.
    case localError(error: NSError)
    
    /// An error occurred during the data task work.
    /// This case indicates an error that occurred while processing the network request.
    @available(*, deprecated, renamed: "localError")
    case error(error: NSError)
    
    /// The network request was cancelled before completion.
    /// This case indicates that the request was intentionally cancelled by the user or system.
    case cancelled
}

public class Network: NetworkProtocol {

       
    internal let interceptor: InterceptorProtocol

    /// Governs automatic retries for requests that fail with a retryable HTTP status code.
    internal let retryPolicy: RetryPolicy

    public init(interceptor: InterceptorProtocol, retryPolicy: RetryPolicy = .none) {
        self.interceptor = interceptor
        self.retryPolicy = retryPolicy
    }
    
    // MARK: - SESSION
    internal lazy var session: URLSession = {
        let configuration = configuration
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        return session
    }()
    
    private lazy var configuration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return configuration
    }()
    
    public func get(path: Path) async -> NetworkResult {
        await proceedWithRequest(path: path, method: .get, body: nil)
    }
    
    public func post(path: Path, payload: Encodable) async -> NetworkResult {
        do {
            let requestBody = try JSONEncoder().encode(payload)
            let method: Network.Method = .post(body: requestBody)
            return await proceedWithRequest(path: path, method: method, body: payload)
        } catch let error {
            assertionFailure("Network: Error on Encoding POST body! error: \(error.localizedDescription)")
            return .localError(error: error as NSError)
        }
    }
    
    public func post(path: Path, multipart payload: Part...) async -> NetworkResult {
        let boundary = "\(UUID().uuidString)"
        let body = configureMultipartBody(payload: payload, boundary: boundary)
        let method: Network.Method = .post(body: body)
        return await proceedWithRequest(path: path, method: method, body: body, multiparts: payload, boundary: boundary)
    }
    
    public func post(path: Path, multiparts payload: [any Part]) async -> NetworkResult {
        let boundary = "\(UUID().uuidString)"
        let body = configureMultipartBody(payload: payload, boundary: boundary)
        let method: Network.Method = .post(body: body)
        return await proceedWithRequest(path: path, method: method, body: body, multiparts: payload, boundary: boundary)
    }
    
    public func put(path: Path, payload: Data) async -> NetworkResult {
        let method: Network.Method = .put(body: payload)
        return await proceedWithRequest(path: path, method: method, body: payload)
    }
    
    public func put(path: Path, multipart payload: Part...) async -> NetworkResult {
        
        let boundary = "\(UUID().uuidString)"
        let body = configureMultipartBody(payload: payload, boundary: boundary)
        
        let method: Network.Method = .put(body: body)
        return await proceedWithRequest(path: path, method: method, body: body, multiparts: payload, boundary: boundary)
    }
    
    public func put(path: Path, multiparts payload: [any Part]) async -> NetworkResult {
        let boundary = "\(UUID().uuidString)"
        let body = configureMultipartBody(payload: payload, boundary: boundary)
        
        let method: Network.Method = .put(body: body)
        return await proceedWithRequest(path: path, method: method, body: body, multiparts: payload, boundary: boundary)
    }
    
    public func patch(path: Path, payload: Encodable) async -> NetworkResult {
        do {
            let requestBody = try JSONEncoder().encode(payload)
            let method: Network.Method = .patch(body: requestBody)
            return await proceedWithRequest(path: path, method: method, body: payload)
        } catch let error {
            assertionFailure("Network: Error on Encoding PATCH body! error: \(error.localizedDescription)")
            return .localError(error: error as NSError)
        }
    }

    public func head(path: Path) async -> NetworkResult {
        await proceedWithRequest(path: path, method: .head, body: nil)
    }

    public func options(path: Path) async -> NetworkResult {
        await proceedWithRequest(path: path, method: .options, body: nil)
    }

    public func delete(path: Path) async -> NetworkResult {
        let method: Network.Method = .delete(body: nil)
        return await proceedWithRequest(path: path, method: method, body: nil)
    }
    
    public func delete(path: Path, body: Data) async -> NetworkResult {
        let method: Network.Method = .delete(body: body)
        return await proceedWithRequest(path: path, method: method, body: body)
    }
    
    
    public func configureMultipartBody(payload: [Part], boundary: String) -> Data {
        
        let body = interceptor.beforeInterceptionBodyCreatorFor(multiparts: payload, boundary: boundary)
        return body
    }
}
