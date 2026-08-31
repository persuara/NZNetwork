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
        let fileURL = interceptor.multipartBodyFileURL(multiparts: payload, boundary: boundary)
        let method: Network.Method = .post(body: Data())
        return try await proceedWithRequest(path: path, method: method, body: nil, multiparts: payload, boundary: boundary, bodyFileURL: fileURL)
    }

    public func putThrowable(path: Path, payload: any Encodable) async throws -> Data {
        let encodedData = try JSONEncoder().encode(payload)
        let method: Network.Method = .put(body: encodedData)
        return try await proceedWithRequest(path: path, method: method, body: payload)
    }

    public func putThrowable(path: Path, multipart payload: any Part...) async throws -> Data {
        let boundary = "\(UUID().uuidString)"
        let fileURL = interceptor.multipartBodyFileURL(multiparts: payload, boundary: boundary)
        let method: Network.Method = .put(body: Data())
        return try await proceedWithRequest(path: path, method: method, body: nil, multiparts: payload, boundary: boundary, bodyFileURL: fileURL)
    }

    public func putThrowable(path: Path, multipart payload: any Part..., mimeType: MIMEType) async throws -> Data {
        let boundary = "\(UUID().uuidString)"
        let fileURL = interceptor.multipartBodyFileURL(multiparts: payload, boundary: boundary)
        let method: Network.Method = .put(body: Data())
        return try await proceedWithRequest(path: path, method: method, body: nil, multiparts: payload, boundary: boundary, bodyFileURL: fileURL)
    }

    public func patchThrowable(path: Path, payload: any Encodable) async throws -> Data {
        let requestBody = try JSONEncoder().encode(payload)
        let method: Network.Method = .patch(body: requestBody)
        return try await proceedWithRequest(path: path, method: method, body: payload)
    }

    public func postFormThrowable(path: Path, form: FormBody) async throws -> Data {
        let method: Network.Method = .post(body: form.encoded)
        return try await proceedWithRequest(path: path, method: method, body: nil, contentType: FormBody.contentType)
    }

    public func putFormThrowable(path: Path, form: FormBody) async throws -> Data {
        let method: Network.Method = .put(body: form.encoded)
        return try await proceedWithRequest(path: path, method: method, body: nil, contentType: FormBody.contentType)
    }

    public func patchFormThrowable(path: Path, form: FormBody) async throws -> Data {
        let method: Network.Method = .patch(body: form.encoded)
        return try await proceedWithRequest(path: path, method: method, body: nil, contentType: FormBody.contentType)
    }

    public func headThrowable(path: Path) async throws -> Data {
        try await proceedWithRequest(path: path, method: .head, body: nil)
    }

    public func optionsThrowable(path: Path) async throws -> Data {
        try await proceedWithRequest(path: path, method: .options, body: nil)
    }

    public func deleteThrowable(path: Path) async throws -> Data {
        try await proceedWithRequest(path: path, method: .delete(body: nil), body: nil)
    }
}
