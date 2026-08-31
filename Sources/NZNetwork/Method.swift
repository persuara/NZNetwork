import Foundation

public extension Network {
    
    /// An enumeration representing HTTP request methods.
    enum Method: RawRepresentable {
        /// The GET method.
        case get
        
        /// The POST method with a request body.
        case post(body: Data)
        
        /// The PUT method with a request body.
        case put(body: Data)
        
        /// The DELETE method.
        case delete(body: Data?)

        /// The PATCH method with a request body.
        case patch(body: Data)

        /// The HEAD method.
        case head

        /// The OPTIONS method.
        case options

        /// The raw value type for the enumeration.
        public typealias RawValue = String

        /// The string representation of the HTTP method.
        public var rawValue: String {
            switch self {
            case .get: return "GET"
            case .post: return "POST"
            case .put: return "PUT"
            case .delete: return "DELETE"
            case .patch: return "PATCH"
            case .head: return "HEAD"
            case .options: return "OPTIONS"
            }
        }

        public var requestBody: Encodable? {
            switch self {
            case .get: return nil
            case .post(let body):
                return body
            case .put(let body):
                return body
            case .delete(let body):
                return body
            case .patch(let body):
                return body
            case .head: return nil
            case .options: return nil
            }
        }
        
        public init?(rawValue: String) { assertionFailure("Network.Method: optional init is unavailable!"); return nil }
    }
}
