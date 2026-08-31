import Foundation

public extension URL {
    
    /// Initializes a URL object using the provided base endpoint, route, and optional query items.
        ///
        /// This initializer constructs a URL by combining the base endpoint, route, and query items.
        /// If the route starts with "http", the route itself is used as the URL.
        /// Otherwise, the URL is constructed using the base endpoint and route with proper formatting.
        ///
        /// - Parameters:
        ///   - baseEndPoint: The base endpoint URL string.
        ///   - route: The route for the network request.
        ///   - queryItems: Optional query items to include in the URL.
    init(baseEndPoint: String, route: String, queryItems: [URLQueryItem]?) {
        if route.starts(with: "http") {
            self.init(string: route)!
            
        } else {
            
            let endPointProtocol: String = "https"
            let finalString = endPointProtocol.networkProtocolSuffix().add(component: baseEndPoint).forwardSlashWhenNeeded().add(component: route.strippingLeadingSlash())
            
            guard var urlComponents = URLComponents(string: finalString) else {
                fatalError("URLComponents(string:) failed to produce results with string: \(finalString)")
            }
            urlComponents.queryItems = queryItems
            
            guard let absoluteString = urlComponents.url?.absoluteString else {
                fatalError("URLComponents: URL Object produced nil. URL seems to be invalid with string: \(finalString)")
            }
            
            self.init(string: absoluteString)!
        }
    }
}

fileprivate extension String {
    
    /// Appends the network protocol suffix to the string (e.g., "http://").
        ///
        /// - Returns: The string with the network protocol suffix added.
    func networkProtocolSuffix() -> String {
        self + "://"
    }
    
    /// Ensures that the string ends with a forward slash ("/") when needed.
        ///
        /// - Returns: The string with a forward slash added if needed.
    func forwardSlashWhenNeeded() -> String {
        if self.hasSuffix("/") {
            return self
        } else {
            return self + "/"
        }
    }
    
    /// Appends the given component to the string.
        ///
        /// - Parameter component: The component to be added to the string.
        /// - Returns: The string with the added component.
    func add(component: String) -> String {
        self + component
    }

    /// Removes a single leading "/", if present — used so a route can be given either with or
    /// without one without producing a doubled slash when joined onto the base URL.
    func strippingLeadingSlash() -> String {
        hasPrefix("/") ? String(dropFirst()) : self
    }
}
