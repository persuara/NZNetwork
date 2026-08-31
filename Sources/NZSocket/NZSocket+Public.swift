import Foundation
import NZNetworkShared

extension NZSocket: NZSocketProtocol {

    public func connect(to path: Path, protocols: [String] = []) {
        lastPath = path
        lastProtocols = protocols
        isExplicitDisconnect = false

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
        isExplicitDisconnect = true
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
                self.stopHeartbeat()
                self.handleUnexpectedDisconnect(error: error)
            }
        }
    }

    /// Starts the periodic ping loop if `heartbeatInterval` is configured.
    func startHeartbeatIfNeeded() {
        guard let heartbeatInterval, heartbeatInterval > 0 else { return }
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(heartbeatInterval * 1_000_000_000))
                guard !Task.isCancelled, let self, self.isConnected else { return }
                try? await self.sendPing()
            }
        }
    }

    /// Stops the periodic ping loop.
    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    /// Decides whether to auto-reconnect after a disconnect, or finish the `messages()` stream.
    ///
    /// Reconnecting keeps the existing `messageContinuation` alive (rather than finishing it), so
    /// a consumer's `for try await` loop over `messages()` transparently keeps receiving messages
    /// once the new connection is established.
    func handleUnexpectedDisconnect(error: Error?) {
        guard !isExplicitDisconnect, let lastPath else {
            messageContinuation?.finish(throwing: error)
            return
        }

        reconnectAttempt += 1
        guard let delay = reconnectPolicy.delayBeforeReconnecting(attempt: reconnectAttempt) else {
            messageContinuation?.finish(throwing: error)
            return
        }

        delegate?.socket(self, willReconnectAttempt: reconnectAttempt, after: delay)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !self.isExplicitDisconnect else { return }
            self.connect(to: lastPath, protocols: self.lastProtocols)
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
