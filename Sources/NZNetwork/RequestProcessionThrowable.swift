import Foundation

extension Network {
    /// Perform a network request with the specified path, method, and optional body.
    ///
    /// - Parameters:
    ///   - path: The API path that defines the route and optional query parameters for the request.
    ///   - method: The HTTP method to use for the request (e.g., GET, POST, PUT, DELETE).
    ///   - body: An optional `Encodable` object that will be included in the request body, if applicable.
    /// - Returns: The response data from the network request.
    /// - Throws: `NetworkError` if there is an issue with the request, such as a network failure, server-side error, or cancellation.
    ///
    /// This method constructs the URL using the provided `Path`, attaches headers, and processes the request
    /// through an `Interceptor` for additional modifications (e.g., adding authentication tokens). Once the
    /// request is intercepted, it is executed, and the response data is returned.
    ///
    /// ## Note:
    /// This API was added to provide a throwable version of the `proceedWithRequest` method for improved error handling,
    /// allowing consumers to catch and handle errors using Swift's `throws` mechanism.
    internal func proceedWithRequest(path: Path, method: Method, body: Encodable?, multiparts: [Part]? = nil, boundary: String? = nil, contentType: String? = nil, bodyFileURL: URL? = nil) async throws -> Data {
        // Construct the URL based on the provided parameters
        let url = URL(baseEndPoint: interceptor.baseURL, route: path.route, queryItems: path.queryItems)

        // Initialize headers (Note: You may need to populate headers accordingly)
        var headers: [String: String] = [:]
        headers = interceptor.setupingInitialHeaders(headers, boundary: boundary)
        if let contentType, boundary == nil {
            headers["Content-Type"] = contentType
        }

        // Create the initial request to be intercepted
        let requestToBeIntercepted = InterceptorRequest(
            url: url,
            method: method,
            headers: headers,
            timeout: path.timeout ?? interceptor.timeout,
            cachePolicy: path.cachePolicy ?? sessionConfiguration.cachePolicy,
            body: body,
            multiparts: multiparts,
            bodyFileURL: bodyFileURL
        )

        // Intercept the request
        let interceptedRequest = try await interceptor.interceptThrowable(request: requestToBeIntercepted)

        return try await createDataTask(with: interceptedRequest)
    }

    internal func createDataTask(with request: InterceptorRequest, attempt: Int = 1) async throws -> Data {

        defer {
            if let bodyFileURL = request.bodyFileURL {
                try? FileManager.default.removeItem(at: bodyFileURL)
            }
        }

        logger?.log(request: request)

        let dataAndResponse: (Data, URLResponse)
        do {
            dataAndResponse = try await createDataTask(url: request.url, headers: request.headers, timeout: request.timeout, cachePolicy: request.cachePolicy, method: request.method, bodyFileURL: request.bodyFileURL)
        } catch {
            let mappedError = error.isCancellationError ? CancellationError() : error
            logger?.log(error: mappedError, for: request)
            throw mappedError
        }

        let data = dataAndResponse.0
        let response = dataAndResponse.1
        
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.localError(
                NSError(domain: "Couldn't catch HTTPURLResponse", code: 0, userInfo: nil)
            )
        }
        
        let statusCode = response.statusCode
        let localizedMessageForStatusCode = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
        
        let responseToBeIntercepted: InterceptorResponse
        
        var responseHeaders: [String: String] = [:]
        response.allHeaderFields.forEach { (key, value) in
            if let key = key.base as? String {
                responseHeaders[key] = "\(value)"
            }
        }
        responseToBeIntercepted = InterceptorResponse(
            request: request,
            localizedMessageForStatusCode: localizedMessageForStatusCode,
            statusCode: statusCode,
            headers: responseHeaders,
            result: .response(data: data)
        )
        
        let interceptedResponse = try await interceptor.interceptThrowable(response: responseToBeIntercepted)
        logger?.log(response: interceptedResponse, data: data)

        switch interceptedResponse.result {
        case .response(let data):
            guard (200...299).contains(statusCode) else {
                if let delay = retryPolicy.delayBeforeRetrying(statusCode: statusCode, attempt: attempt) {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await createDataTask(with: request, attempt: attempt + 1)
                }
                throw NetworkError.remoteError(data)
            }
            return data
        case .error(let error):
            throw NetworkError.localError(error)
        case .close:
            throw NetworkError.localError(
                NSError(domain: "Request closed", code: 0, userInfo: nil)
            )
        case .proceed(let request):
            return try await createDataTask(with: request, attempt: attempt)
        }
    }
}
