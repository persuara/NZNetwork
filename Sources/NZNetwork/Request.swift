import Foundation

internal extension Network {
    
    /// Creates and returns a URLRequest with the specified URL and timeout interval.
    ///
    /// This function constructs a URLRequest using the provided URL and timeout interval,
    /// utilizing the cache policy from the current session's configuration.
    ///
    /// - Parameters:
    ///   - url: The URL to be used in the URLRequest.
    ///   - timeout: The timeout interval for the URLRequest.
    /// - Returns: A newly created URLRequest instance.
    func createRequest(url: URL, timeout: TimeInterval) -> URLRequest {
        // Create a URLRequest with the given URL, using the session's cache policy and timeout interval
        let request = URLRequest(url: url, cachePolicy: session.configuration.requestCachePolicy, timeoutInterval: timeout)
        return request
    }
}
