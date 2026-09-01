import Foundation
import NZNetworkShared

/// Streaming responses — for Server-Sent Events, newline-delimited JSON, or any endpoint where
/// you want to start processing the response as it arrives, rather than waiting for `get`/
/// `getThrowable` to buffer the whole body first.
public extension Network {

    /// Streams the response body for a GET request, yielding raw byte chunks as they arrive.
    ///
    /// Unlike `get`/`getThrowable`, this doesn't wait for the full response before returning
    /// data, and it doesn't participate in `RetryPolicy` (retrying mid-stream isn't meaningful).
    /// A non-2xx status code throws `NetworkError.remoteError` before any chunk is yielded.
    ///
    /// - Parameters:
    ///   - path: The path to request.
    ///   - chunkSize: The approximate number of bytes to buffer before yielding a chunk (default 16 KB).
    @available(iOS 15.0, *)
    func stream(path: Path, chunkSize: Int = 16 * 1024) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try await streamingRequest(for: path)
                    let (bytes, response) = try await session.bytes(for: request)
                    try await Self.throwIfNotSuccessful(response: response, bytes: bytes)

                    var buffer = Data()
                    buffer.reserveCapacity(chunkSize)
                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= chunkSize {
                            continuation.yield(buffer)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error.isCancellationError ? CancellationError() : error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Streams the response body for a GET request as text lines — convenient for
    /// newline-delimited JSON or Server-Sent Events (`data: ...` frames).
    ///
    /// Same behavior/caveats as `stream(path:chunkSize:)` regarding retries and status codes.
    @available(iOS 15.0, *)
    func streamLines(path: Path) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try await streamingRequest(for: path)
                    let (bytes, response) = try await session.bytes(for: request)
                    try await Self.throwIfNotSuccessful(response: response, bytes: bytes)

                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error.isCancellationError ? CancellationError() : error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension Network {

    /// Builds the intercepted `URLRequest` used by `stream`/`streamLines`.
    func streamingRequest(for path: Path) async throws -> URLRequest {
        let url = URL(baseEndPoint: interceptor.baseURL, route: path.route, queryItems: path.queryItems)
        let headers = interceptor.setupingInitialHeaders([:], boundary: nil)
        let requestToBeIntercepted = InterceptorRequest(
            url: url,
            method: .get,
            headers: headers,
            timeout: path.timeout ?? interceptor.timeout,
            cachePolicy: path.cachePolicy ?? sessionConfiguration.cachePolicy,
            body: nil,
            multiparts: nil
        )
        let interceptedRequest = await interceptor.intercept(request: requestToBeIntercepted)

        var request = URLRequest(url: interceptedRequest.url, cachePolicy: interceptedRequest.cachePolicy, timeoutInterval: interceptedRequest.timeout)
        request.setHeaders(interceptedRequest.headers)
        request.asGet()
        return request
    }

    /// Drains `bytes` into `NetworkError.remoteError` if the response wasn't a 2xx, before any
    /// chunk has been yielded to the caller.
    @available(iOS 15.0, *)
    static func throwIfNotSuccessful(response: URLResponse, bytes: URLSession.AsyncBytes) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.localError(
                NSError(domain: "Couldn't catch HTTPURLResponse", code: 0, userInfo: nil)
            )
        }
        guard !(200...299).contains(httpResponse.statusCode) else { return }

        var errorData = Data()
        for try await byte in bytes {
            errorData.append(byte)
        }
        throw NetworkError.remoteError(errorData)
    }
}
