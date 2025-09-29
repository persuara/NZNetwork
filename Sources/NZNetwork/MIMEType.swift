import Foundation

/// Multipurpose Internet Mail Extensions or MIME type) indicates the nature and format of a document, file, or assortment of bytes.
/// MIME types are defined and standardized in IETF's RFC 6838.
public enum MIMEType {
    
    public init?(mimeType: String) {
        let isValid = MIMETypeValidator.isValid(mimeType)
        if isValid {
            self = .custom(mimeType: mimeType)
        } else {
            preconditionFailure("NZNetwork: \(mimeType) is not a valid mimeType")
            return nil
        }
    }
    
    case image(subtype: ImageSubtype)
    case video(subtype: VideoSubtype)
    case audio(subtype: AudioSubtype)
    case document(subtype: DocumentSubtype)
    /// Default MIMEType
    case octetStream
    case text(subType: TextSubtype)
    case custom(mimeType: String)
    
    public var mimeType: String? {
        return (type != nil) && (subtype != nil) ?  type! + "/" + subtype! : nil
    }
}

extension MIMEType {
    /// An enum representing image subtypes corresponding to specific image file formats.
    /// Each case represents a valid image subtype used in MIME types.
    public enum ImageSubtype: String {
        /// Joint Photographic Expert Group image (JPEG)
        case jpeg
        /// Portable Network Graphics (PNG)
        case png
        /// Graphics Interchange Format (GIF)
        case gif
        /// Bitmap image file (BMP)
        case bmp
        /// Tagged Image File Format (TIFF)
        case tiff
        /// Web Picture format (WEBP)
        case webp
        /// Animated Portable Network Graphics (APNG)
        case apng
        /// AV1 Image File Format (AVIF)
        case avif
        /// Scalable Vector Graphics (SVG)
        case svg = "svg+xml"
    }
    
    /// An enum representing video subtypes corresponding to specific video file formats.
    /// Each case represents a valid video subtype used in MIME types.
    public enum VideoSubtype: String {
        /// MPEG-4 video format (MP4)
        case mp4
        /// WebM video format (WEBM)
        case webm
        /// QuickTime movie format (MOV)
        case mov = "quicktime"
        /// Microsoft AVI format (AVI)
        case avi = "x-msvideo"
        /// Matroska multimedia container format (MKV)
        case mkv = "x-matroska"
    }
    
    /// An enum representing audio subtypes corresponding to specific audio file formats.
    /// Each case represents a valid audio subtype used in MIME types.
    public enum AudioSubtype: String {
        /// MPEG Audio Layer III (MP3)
        case mp3 = "mpeg"
        /// Waveform Audio File Format (WAV)
        case wav
        /// Advanced Audio Codec (AAC)
        case aac
        /// Ogg Vorbis Audio Format (OGG)
        case ogg
        /// Free Lossless Audio Codec (FLAC)
        case flac
    }
    
    /// An enum representing document subtypes corresponding to specific document file formats.
    /// Each case represents a valid document subtype used in MIME types.
    public enum DocumentSubtype: String {
        /// Portable Document Format (PDF)
        case pdf
        /// JavaScript Object Notation (JSON)
        case json
        /// Extensible Markup Language (XML)
        case xml
        /// ZIP archive format (ZIP)
        case zip
    }
    
    
    /// An enum representing text document subtypes corresponding to specific text-based MIME types.
    /// Each case represents a valid text subtype used in MIME types under the `text/` media type.
    public enum TextSubtype: RawRepresentable {
        
        public typealias RawValue = String
        
        public init?(rawValue: String) { nil }
        
        /// Plain text (`text/plain`)
        case plain(charset: Charset = .utf8)
        /// HyperText Markup Language (`text/html`)
        case html(charset: Charset = .utf8)
        /// Cascading Style Sheets (`text/css`)
        case css(charset: Charset = .utf8)
        /// Comma-separated values (`text/csv`)
        case csv(charset: Charset = .utf8)
        /// JavaScript (`text/javascript`)
        case javascript(charset: Charset = .utf8)
        /// Extensible Markup Language (`text/xml`)
        case xml(charset: Charset = .utf8)
        /// Markdown formatted text (`text/markdown`)
        case markdown(charset: Charset = .utf8)
        /// iCalendar format (`text/calendar`)
        case calendar(charset: Charset = .utf8)
        /// Rich Text Format variant (`text/richtext`)
        case richtext(charset: Charset = .utf8)
        
        public var rawValue: RawValue {
            switch self {
            case .plain(let charset): return "plain; charset=\(charset.rawValue)"
            case .html(let charset): return "html; charset=\(charset.rawValue)"
            case .css(let charset): return "css; charset=\(charset.rawValue)"
            case .csv(let charset): return "csv; charset=\(charset.rawValue)"
            case .javascript(let charset): return "javascript; charset=\(charset.rawValue)"
            case .xml(let charset): return "xml; charset=\(charset.rawValue)"
            case .markdown(let charset): return "markdown; charset=\(charset.rawValue)"
            case .calendar(let charset): return "calendar; charset=\(charset.rawValue)"
            case .richtext(let charset): return "richtext; charset=\(charset.rawValue)"
            }
        }
        
        /// An enum representing common character set (charset) values used in the `charset` parameter
        /// of MIME types to specify the encoding of textual content.
        ///
        /// Each case corresponds to a widely recognized character encoding standard.
        ///
        /// Usage of these charset values helps clients correctly decode the textual content.
        public enum Charset: String {
            /// Unicode UTF-8 encoding (most common and recommended)
            case utf8 = "utf-8"
            /// ASCII encoding (7-bit, basic Latin)
            case usASCII = "us-ascii"
            /// Western European (Latin-1) encoding
            case iso88591 = "iso-8859-1"
            /// Central and Eastern European encoding
            case iso88592 = "iso-8859-2"
            /// Microsoft’s Latin-1 superset encoding
            case windows1252 = "windows-1252"
            /// Unicode UTF-16 encoding (16-bit)
            case utf16 = "utf-16"
            /// UTF-16 big-endian encoding
            case utf16BE = "utf-16be"
            /// UTF-16 little-endian encoding
            case utf16LE = "utf-16le"
            /// Alias for ISO-8859-1 encoding
            case latin1 = "latin1"
        }
    }
}

extension MIMEType {
    
    private var type: String? {
        switch self {
        case .image(_): return "image"
        case .video(_): return "video"
        case .audio(_): return "audio"
        case .document(_), .octetStream: return "application"
        case .text(_): return "text"
        case .custom(let mimeType): return mimeType.split(separator: "/").first?.base
        }
    }
    
    private var subtype: String? {
        switch self {
        case .image(let subtype): return subtype.rawValue
        case .video(let subtype): return subtype.rawValue
        case .audio(let subtype): return subtype.rawValue
        case .document(let subtype): return subtype.rawValue
        case .text(let subtype): return subtype.rawValue
        case .octetStream: return "octet-stream"
        case .custom(let mimeType): return mimeType.split(separator: "/").last?.base
        }
    }
}

extension MIMEType {
    
    /// - Returns: MimeType object of a file extension
    ///
    ///     Example:
    ///         let mimeType = MIMEType.from(fileExtension: "jpg")
    //          print(mimeType.rawValue) -> Output: "image/jpeg"
    public static func sniff(fileExtension: String) -> MIMEType {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg": return .image(subtype: .jpeg)
        case "png"        : return .image(subtype: .png)
        case "gif"        : return .image(subtype: .gif)
        case "bmp"        : return .image(subtype: .bmp)
        case "tiff", "tif": return .image(subtype: .tiff)
        case "webp"       : return .image(subtype: .webp)
        case "mp4"        : return .video(subtype: .mp4)
        case "mov"        : return .video(subtype: .mov)
        case "avi"        : return .video(subtype: .avi)
        case "mkv"        : return .video(subtype: .mkv)
        case "webm"       : return .video(subtype: .webm)
        case "mp3"        : return .audio(subtype: .mp3)
        case "wav"        : return .audio(subtype: .wav)
        case "aac"        : return .audio(subtype: .aac)
        case "ogg"        : return .audio(subtype: .ogg)
        case "flac"       : return .audio(subtype: .flac)
        case "pdf"        : return .document(subtype: .pdf)
        case "json"       : return .document(subtype: .json)
        case "xml"        : return .document(subtype: .xml)
        case "zip"        : return .document(subtype: .zip)
        default           : return .octetStream
        }
    }
}

extension MIMEType {
    
    private struct MIMETypeValidator {
        
        /// Validates whether the given MIME type follows the correct structure.
        /// - Parameter mimeType: The MIME type string to validate.
        /// - Returns: `true` if the MIME type is valid, otherwise `false`.
        static func isValid(_ mimeType: String) -> Bool {
            let pattern = #"^([a-zA-Z0-9!#$&^_.+-]+)\/([a-zA-Z0-9!#$&^_.+-]+)(;[a-zA-Z0-9!#$&^_.+-]+=[a-zA-Z0-9!#$&^_.+-]+)?$"#
            
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: mimeType.utf16.count)
            
            return regex?.firstMatch(in: mimeType, options: [], range: range) != nil
        }
    }
}

extension MIMEType: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        guard let mimeTypeString = self.mimeType else {
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Cannot encode MIMEType: mimeType string is nil"
            )
            throw EncodingError.invalidValue(self, context)
        }
        
        try container.encode(mimeTypeString)
    }
}
