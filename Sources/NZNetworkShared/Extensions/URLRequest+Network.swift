import Foundation

public extension URLRequest {
    
    private enum Method: String {
        case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
    }
    
    /// This method changes the HTTPMethod value of any given URLRequest to "GET".
    /// This must be the only function called in your stream to change HTTPMethod, otherwise the last HTTPMethod set will override any previous values.
    /// - Returns: The same URLRequest object with a different HTTPMethod value.
    @discardableResult mutating func asGet() -> URLRequest {
        self.httpMethod = Method.get.rawValue
        return self
    }
    
    /// This method changes the HTTPMethod value of any given URLRequest to "POST".
    /// This must be the only function called in your stream to change HTTPMethod, otherwise the last HTTPMethod set will override any previous values.
    /// - Parameter body: This method also requires the httpBody associated with the "POST" HTTPMethod. When a body is not present, an Empty body of "{}" must be generated and provided to it.
    /// - Returns: The same URLRequest object with a different HTTPMethod value.
    @discardableResult mutating func asPost(body: Data) -> URLRequest {
        self.httpMethod = Method.post.rawValue
        self.httpBody = body
        return self
    }
    
    /// This method changes the HTTPMethod value of any given URLRequest to "PUT".
    /// This must be the only function called in your stream to change HTTPMethod, otherwise the last HTTPMethod set will override any previous values.
    /// - Parameter body: This method also requires the httpBody associated with the "PUT" HTTPMethod.
    /// - Returns: The same URLRequest object with a different HTTPMethod value.
    @discardableResult mutating func asPut(body: Data) -> URLRequest {
        self.httpMethod = Method.put.rawValue
        self.httpBody = body
        return self
    }
    
    /// This method changes the HTTPMethod value of any given URLRequest to "DELETE".
    /// This must be the only function called in your stream to change HTTPMethod, otherwise the last HTTPMethod set will override any previous values.
    /// - Returns: The same URLRequest object with a different HTTPMethod value.
    @discardableResult mutating func asDelete(body: Data? = nil) -> URLRequest {
        self.httpMethod = Method.delete.rawValue
        self.httpBody = body
        return self
    }
    
    /// Sets the headers of the URLRequest by applying the provided dictionary of headers.
    ///
    /// This method mutates the current URLRequest instance by setting headers based on the
    /// provided dictionary. Each key-value pair in the dictionary corresponds to a header
    /// field and its associated value.
    ///
    /// - Parameter headers: A dictionary containing header fields and their values.
    /// - Returns: The mutated URLRequest instance with the updated headers.
    @discardableResult mutating func setHeaders(_ headers: [String: String]) -> URLRequest {
        headers.forEach { (key, value) in
            self.setValue(value, forHTTPHeaderField: key)
        }
        return self
    }
}
