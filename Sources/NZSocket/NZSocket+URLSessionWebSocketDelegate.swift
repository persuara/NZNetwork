import Foundation

extension NZSocket: URLSessionWebSocketDelegate {

    /// Tells the delegate that the WebSocket task successfully negotiated the handshake with the server.
    /// - Parameters:
    ///   - session: The session containing the WebSocket task.
    ///   - webSocketTask: The WebSocket task.
    ///   - protocol: The protocol picked by the server out of the offered `protocols`, if any.
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        reconnectAttempt = 0
        startHeartbeatIfNeeded()
        delegate?.socket(self, didConnectWithProtocol: `protocol`)
    }

    /// Tells the delegate that the WebSocket task received a close frame from the server.
    /// - Parameters:
    ///   - session: The session containing the WebSocket task.
    ///   - webSocketTask: The WebSocket task.
    ///   - closeCode: The close code sent by the server.
    ///   - reason: An optional reason payload sent by the server.
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        stopHeartbeat()
        delegate?.socket(self, didDisconnectWithCode: closeCode, reason: reason)
        handleUnexpectedDisconnect(error: nil)
    }

    /// Forwards session-wide authentication challenges (SSL pinning, client certificates,
    /// Basic/NTLM credentials, ...) to `delegate.socket(_:didReceive:)`.
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let delegate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        Task {
            let (disposition, credential) = await delegate.socket(self, didReceive: challenge)
            completionHandler(disposition, credential)
        }
    }
}
