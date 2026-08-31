import Foundation

extension Network: URLSessionDelegate {

    /// Forwards session-wide authentication challenges (SSL pinning, client certificates,
    /// Basic/NTLM credentials, ...) to `interceptor.handle(challenge:)`.
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Task {
            let (disposition, credential) = await interceptor.handle(challenge: challenge)
            completionHandler(disposition, credential)
        }
    }
}
