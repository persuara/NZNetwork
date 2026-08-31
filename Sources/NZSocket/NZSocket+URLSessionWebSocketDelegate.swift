import Foundation

extension NZSocket: URLSessionWebSocketDelegate {

    /// Tells the delegate that the WebSocket task successfully negotiated the handshake with the server.
    /// - Parameters:
    ///   - session: The session containing the WebSocket task.
    ///   - webSocketTask: The WebSocket task.
    ///   - protocol: The protocol picked by the server out of the offered `protocols`, if any.
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
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
        messageContinuation?.finish()
        delegate?.socket(self, didDisconnectWithCode: closeCode, reason: reason)
    }
}
