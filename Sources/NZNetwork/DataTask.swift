import Foundation
import NZNetworkShared

internal extension Network {
    
    /// Creates and returns a URLSessionDataTask with the specified parameters, executed asynchronously.
    ///
    /// This function constructs a URLSessionDataTask based on the provided URL, timeout interval, HTTP method,
    /// and completion handler. The appropriate URLRequest is created based on the HTTP method, and the data
    /// task is initiated with the request. The function is marked as asynchronous and returns a tuple containing
    /// the retrieved data and the URLResponse upon completion.
    ///
    /// - Parameters:
    ///   - url: The URL for the network request.
    ///   - timeout: The timeout interval for the network request.
    ///   - method: The HTTP method for the network request.
    /// - Returns: A tuple containing the retrieved `Data` and the `URLResponse`.
    /// - Throws: An error if there's a problem during the asynchronous data task execution.
    func createDataTask(url: URL, headers: [String: String], timeout: TimeInterval, cachePolicy: URLRequest.CachePolicy, method: Method) async throws -> (Data, URLResponse) {
        // Create the initial request with the given URL, cache policy, and timeout
        var request = createRequest(url: url, timeout: timeout, cachePolicy: cachePolicy)
        request.setHeaders(headers)
        
        // Configure the request based on the specified HTTP method
        switch method {
        case .get:
            request.asGet()
        case .delete(let body):
            request.asDelete(body: body)
        case .post(let body):
            request.asPost(body: body)
        case .put(let body):
            request.asPut(body: body)
        case .patch(let body):
            request.asPatch(body: body)
        case .head:
            request.asHead()
        case .options:
            request.asOptions()
        }
        
        // Perform the asynchronous data task and return the result
        return try await session.data(for: request)
    }
}
