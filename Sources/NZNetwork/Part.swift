import Foundation

public protocol Part: Encodable {
    
    var name: String { get }
    var filename: String? { get }
    var body: Data? { get }
    var value: String? { get }
    var mimeType: MIMEType? { get }
}
