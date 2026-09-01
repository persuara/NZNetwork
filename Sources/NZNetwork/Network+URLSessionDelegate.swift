import Foundation

extension Network: URLSessionTaskDelegate {

    /// Forwards session-wide authentication challenges (SSL pinning, client certificates,
    /// Basic/NTLM credentials, ...) to `interceptor.handle(challenge:)`.
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Task {
            let (disposition, credential) = await interceptor.handle(challenge: challenge)
            completionHandler(disposition, credential)
        }
    }

    /// Forwards HTTP redirects to `interceptor.redirect(from:to:)`.
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        Task {
            let redirectRequest = await interceptor.redirect(from: response, to: request)
            completionHandler(redirectRequest)
        }
    }
}
