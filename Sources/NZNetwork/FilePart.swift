import Foundation

/// A multipart `Part` backed by a file on disk rather than in-memory `Data`, so uploading a large
/// file (a photo, a video) doesn't require loading the whole thing into memory just to attach it.
///
/// Only takes effect with `Network`'s streamed multipart requests (the default for `post`/`put`
/// with `multipart`/`multiparts`) — the file's bytes are read straight from disk in bounded
/// chunks while the request body is assembled.
public struct FilePart: Part {

    public let name: String
    public let filename: String?
    public let bodyFileURL: URL?
    public let mimeType: MIMEType?

    public var body: Data? { nil }
    public var value: String? { nil }

    /// Creates a file-backed multipart part.
    ///
    /// - Parameters:
    ///   - name: The form field name.
    ///   - filename: The filename reported to the server. Defaults to the file URL's last path component.
    ///   - fileURL: The URL of the file on disk to stream as this part's content.
    ///   - mimeType: The MIME type to report. Defaults to sniffing `fileURL`'s extension.
    public init(name: String, filename: String? = nil, fileURL: URL, mimeType: MIMEType? = nil) {
        self.name = name
        self.filename = filename ?? fileURL.lastPathComponent
        self.bodyFileURL = fileURL
        self.mimeType = mimeType ?? .sniff(fileExtension: fileURL.pathExtension)
    }
}
