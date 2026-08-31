import Foundation
import NZNetworkShared

extension NZSocket: NZSocketProtocol {

    public func connect(to path: Path, protocols: [String] = []) {
        let url = URL(baseEndPoint: baseURL, route: path.route, queryItems: path.queryItems)

        var request = URLRequest(url: url, timeoutInterval: timeout)
        protocols.forEach { request.addValue($0, forHTTPHeaderField: "Sec-WebSocket-Protocol") }

        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()
        listen()
    }

    public func messages() -> AsyncThrowingStream<NZSocketMessage, Error> {
        AsyncThrowingStream { continuation in
            self.messageContinuation = continuation
        }
    }

    public func send(_ message: NZSocketMessage) async throws {
        guard let task else {
            throw NZSocketError.notConnected
        }
        try await task.send(message.asURLSessionMessage)
    }

    public func sendPing() async throws {
        guard let task else {
            throw NZSocketError.notConnected
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func disconnect(closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: Data? = nil) {
        task?.cancel(with: closeCode, reason: reason)
    }
}

internal extension NZSocket {

    /// Recursively receives messages from the WebSocket task and forwards them to the `messages()` stream.
    func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.messageContinuation?.yield(message.asNZSocketMessage)
                self.listen()
            case .failure(let error):
                self.isConnected = false
                self.messageContinuation?.finish(throwing: error)
            }
        }
    }
}

internal extension NZSocketMessage {
    var asURLSessionMessage: URLSessionWebSocketTask.Message {
        switch self {
        case .string(let string): return .string(string)
        case .data(let data): return .data(data)
        }
    }
}

internal extension URLSessionWebSocketTask.Message {
    var asNZSocketMessage: NZSocketMessage {
        switch self {
        case .string(let string): return .string(string)
        case .data(let data): return .data(data)
        @unknown default: return .data(Data())
        }
    }
}
