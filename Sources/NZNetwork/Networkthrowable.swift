import Foundation

// MARK: - Throwable APIs
extension Network {

    public func getThrowable(path: Path) async throws -> Data {
        try await proceedWithRequest(path: path, method: .get, body: nil)
    }
    
    public func postThrowable(path: Path, payload: any Encodable) async throws -> Data {
        let requestBody = try JSONEncoder().encode(payload)
        let method: Network.Method = .post(body: requestBody)
        return try await proceedWithRequest(path: path, method: method, body: payload)
    }
    
    public func postThrowable(path: Path, multipart payload: any Part...) async throws -> Data {
        let boundary = "\(UUID().uuidString)"
        let body = configureMultipartBody(payload: payload, boundary: boundary)
        let method: Network.Method = .post(body: body)
        return try await proceedWithRequest(path: path, method: method, body: body, multiparts: payload, boundary: boundary)
    }
    
    public func putThrowable(path: Path, payload: any Encodable) async throws -> Data {
        let encodedData = try JSONEncoder().encode(payload)
        let method: Network.Method = .put(body: encodedData)
        return try await proceedWithRequest(path: path, method: method, body: payload)
    }
    
    public func putThrowable(path: Path, multipart payload: any Part...) async throws -> Data {
        let boundary = "\(UUID().uuidString)"
        let body = configureMultipartBody(payload: payload, boundary: boundary)
        let method: Network.Method = .put(body: body)
        return try await proceedWithRequest(path: path, method: method, body: body, multiparts: payload, boundary: boundary)
    }
    
    public func putThrowable(path: Path, multipart payload: any Part..., mimeType: MIMEType) async throws -> Data {
        let boundary = "\(UUID().uuidString)"
        let body = configureMultipartBody(payload: payload, boundary: boundary)
        let method: Network.Method = .put(body: body)
        return try await proceedWithRequest(path: path, method: method, body: body, multiparts: payload, boundary: boundary)
    }
    
    public func deleteThrowable(path: Path) async throws -> Data {
        try await proceedWithRequest(path: path, method: .delete(body: nil), body: nil)
    }
}
