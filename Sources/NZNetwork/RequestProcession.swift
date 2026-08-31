import Foundation
import NZNetworkShared

extension Network {
    /// Proceeds with sending a network request with the given parameters, intercepting and handling the response.
    ///
    /// This method performs a network request by creating an `InterceptorRequest` based on the provided parameters,
    /// intercepts the request, sends the request using `URLSession`, and handles the response. The intercepted response
    /// is further processed by the interceptor and passed to the provided callback.
    ///
    /// - Parameters:
    ///   - path: The `Path` object representing the API route and query items for the request.
    ///   - method: The HTTP method to be used for the request.
    ///   - body: An optional `Encodable` payload to be included in the request body.
    ///   - callback: A closure that receives a `NetworkCallback` object containing the response data, error information,
    ///               and additional details. The closure is invoked when the request completes.
    internal func proceedWithRequest(path: Path, method: Method, body: Encodable?, multiparts: [Part]? = nil, boundary: String? = nil, contentType: String? = nil, bodyFileURL: URL? = nil) async -> NetworkResult {
        // Construct the URL based on the provided parameters
        let url = URL(baseEndPoint: interceptor.baseURL, route: path.route, queryItems: path.queryItems)

        // Initialize headers (Note: You may need to populate headers accordingly)
        var headers = [String: String]()
        headers = interceptor.setupingInitialHeaders(headers, boundary: boundary)
        if let contentType, boundary == nil {
            headers["Content-Type"] = contentType
        }

        // Create the initial request to be intercepted
        let requestToBeIntercepted = InterceptorRequest(url: url, method: method, headers: headers, timeout: path.timeout ?? interceptor.timeout, cachePolicy: path.cachePolicy ?? sessionConfiguration.cachePolicy, body: body, multiparts: multiparts, bodyFileURL: bodyFileURL)

        // Intercept the request
        let interceptedRequest = await interceptor.intercept(request: requestToBeIntercepted)

        return await createDataTask(with: interceptedRequest)
    }

    internal func createDataTask(with request: InterceptorRequest, attempt: Int = 1) async -> NetworkResult {

        defer {
            if let bodyFileURL = request.bodyFileURL {
                try? FileManager.default.removeItem(at: bodyFileURL)
            }
        }

        do {
            let dataAndResponse = try await createDataTask(url: request.url, headers: request.headers, timeout: request.timeout, cachePolicy: request.cachePolicy, method: request.method, bodyFileURL: request.bodyFileURL)
            
            let data = dataAndResponse.0
            let dataTaskResponse = dataAndResponse.1
            
            let response = dataTaskResponse as! HTTPURLResponse
            
            let statusCode = response.statusCode
            let localizedMessageForStatusCode = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            
            let responseToBeIntercepted: InterceptorResponse
            
            var responseHeaders = [String: String]()
            response.allHeaderFields.forEach { (key, value) in
                if let key = key.base as? String {
                    responseHeaders[key] = "\(value)"
                }
            }
            responseToBeIntercepted = InterceptorResponse(request: request, localizedMessageForStatusCode: localizedMessageForStatusCode, statusCode: statusCode, headers: responseHeaders, result: .response(data: data))
            
            let interceptedResponse = await interceptor.intercept(response: responseToBeIntercepted)
            
            switch interceptedResponse.result {
            case .response(let data):
                if (200...299).contains(statusCode) {
                    return .success(response: data)
                } else if let delay = retryPolicy.delayBeforeRetrying(statusCode: statusCode, attempt: attempt) {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        return .cancelled
                    }
                    return await createDataTask(with: request, attempt: attempt + 1)
                } else {
                    return .remoteError(response: data)
                }
            case .error(let error):
                return .localError(error: error)
            case .close: return .cancelled
            case .proceed(let request):
                return await createDataTask(with: request, attempt: attempt)
            }
        } catch let error {

            if error.isCancellationError {
                return .cancelled
            }

            let error = error as NSError
            let responseToBeIntercepted = InterceptorResponse(request: request, localizedMessageForStatusCode: "", statusCode: error.code, headers: request.headers, result: .error(error: error))
            let interceptedResponse = await interceptor.intercept(response: responseToBeIntercepted)
            
            switch interceptedResponse.result {
            case .response(let data):
                return .success(response: data)
            case .error(let error):
                return .localError(error: error)
            case .close: return .cancelled
            case .proceed(let request):
                return await createDataTask(with: request)
            }
        }
    }
}
