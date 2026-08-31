import Foundation

/// Typed decoding sugar on top of the `...Throwable` APIs, so callers don't have to decode
/// `Data` manually at every call site. Decoding errors propagate as the raw `DecodingError`
/// Foundation throws, same as encoding errors do on the existing `...Throwable` methods.
public extension NetworkProtocol {

    /// Performs a GET request and decodes the JSON response as `T`.
    func getDecoded<T: Decodable>(path: Path, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        try decoder.decode(T.self, from: try await getThrowable(path: path))
    }

    /// Performs a POST request and decodes the JSON response as `T`.
    func postDecoded<T: Decodable>(path: Path, payload: Encodable, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        try decoder.decode(T.self, from: try await postThrowable(path: path, payload: payload))
    }

    /// Performs a PUT request and decodes the JSON response as `T`.
    func putDecoded<T: Decodable>(path: Path, payload: Encodable, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        try decoder.decode(T.self, from: try await putThrowable(path: path, payload: payload))
    }

    /// Performs a PATCH request and decodes the JSON response as `T`.
    func patchDecoded<T: Decodable>(path: Path, payload: Encodable, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        try decoder.decode(T.self, from: try await patchThrowable(path: path, payload: payload))
    }

    /// Performs a DELETE request and decodes the JSON response as `T`.
    func deleteDecoded<T: Decodable>(path: Path, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        try decoder.decode(T.self, from: try await deleteThrowable(path: path))
    }
}
