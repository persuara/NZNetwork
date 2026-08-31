import Foundation

/// A handle to a single in-flight `Network` request, obtained from one of the `...Cancellable`
/// methods below. Unlike the plain `async` request methods, this lets you cancel the request
/// from outside without having to manage your own wrapping `Task`.
public final class NetworkTask: Sendable {

    private let task: Task<NetworkResult, Never>

    internal init(task: Task<NetworkResult, Never>) {
        self.task = task
    }

    /// The request's result. Suspends until the request completes.
    /// If `cancel()` was called before completion, this resolves to `.cancelled`.
    public var result: NetworkResult {
        get async { await task.value }
    }

    /// Cancels the in-flight request.
    public func cancel() {
        task.cancel()
    }
}

public extension Network {

    /// Perform a GET request that can be cancelled before it completes.
    @discardableResult
    func getCancellable(path: Path) -> NetworkTask {
        NetworkTask(task: Task { await self.get(path: path) })
    }

    /// Perform a POST request that can be cancelled before it completes.
    @discardableResult
    func postCancellable(path: Path, payload: Encodable) -> NetworkTask {
        NetworkTask(task: Task { await self.post(path: path, payload: payload) })
    }

    /// Perform a PUT request that can be cancelled before it completes.
    @discardableResult
    func putCancellable(path: Path, payload: Data) -> NetworkTask {
        NetworkTask(task: Task { await self.put(path: path, payload: payload) })
    }

    /// Perform a PATCH request that can be cancelled before it completes.
    @discardableResult
    func patchCancellable(path: Path, payload: Encodable) -> NetworkTask {
        NetworkTask(task: Task { await self.patch(path: path, payload: payload) })
    }

    /// Perform a DELETE request that can be cancelled before it completes.
    @discardableResult
    func deleteCancellable(path: Path) -> NetworkTask {
        NetworkTask(task: Task { await self.delete(path: path) })
    }

    /// Perform a DELETE request with a body that can be cancelled before it completes.
    @discardableResult
    func deleteCancellable(path: Path, body: Data) -> NetworkTask {
        NetworkTask(task: Task { await self.delete(path: path, body: body) })
    }
}
