import Foundation

public protocol Part: Encodable {

    var name: String { get }
    var filename: String? { get }
    var body: Data? { get }

    /// The URL of a file on disk to stream as this part's content, as an alternative to loading
    /// it into `body` up front. When both `body` and `bodyFileURL` are provided, `bodyFileURL`
    /// takes precedence.
    ///
    /// Only honored by `Network`'s streamed multipart requests (the default for `post`/`put`
    /// with `multipart`/`multiparts`) — reading straight from disk in bounded chunks instead of
    /// loading the whole file into memory first, which matters for large files (photos, videos).
    /// Default `nil`.
    var bodyFileURL: URL? { get }

    var value: String? { get }
    var mimeType: MIMEType? { get }
}

public extension Part {
    var bodyFileURL: URL? { nil }
}
