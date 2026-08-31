import Foundation

/// A body encoded as `application/x-www-form-urlencoded`, for endpoints that expect classic
/// HTML-form-style bodies instead of JSON or multipart.
public struct FormBody {

    /// The MIME type to send as the request's `Content-Type` header.
    public static let contentType = "application/x-www-form-urlencoded; charset=utf-8"

    /// The form fields, in the order they'll be encoded.
    public let items: [URLQueryItem]

    /// Creates a form body from ordered query items.
    public init(_ items: [URLQueryItem]) {
        self.items = items
    }

    /// Creates a form body from a dictionary. Dictionaries have no defined order, so prefer
    /// `init(_:[URLQueryItem])` if field order matters to the server.
    public init(_ parameters: [String: String]) {
        self.items = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    /// The percent-encoded `application/x-www-form-urlencoded` body data.
    public var encoded: Data {
        let pairs = items.map { item -> String in
            let name = item.name.formURLEncoded()
            let value = (item.value ?? "").formURLEncoded()
            return "\(name)=\(value)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }
}

private extension String {
    /// Percent-encodes a string per `application/x-www-form-urlencoded` (spaces become `+`,
    /// unlike standard URL query percent-encoding, which leaves them as `%20`).
    func formURLEncoded() -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let percentEncoded = addingPercentEncoding(withAllowedCharacters: allowed) ?? self
        return percentEncoded.replacingOccurrences(of: "%20", with: "+")
    }
}
