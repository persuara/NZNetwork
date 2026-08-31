import Foundation
import NZNetworkShared

/// A protocol defining the contract for intercepting and modifying network requests and responses.
public protocol InterceptorProtocol {
    /// The base URL for network requests.
    var baseURL: String { get }
    
    /// The timeout interval for network requests.
    var timeout: TimeInterval { get }
    
    /// Intercepts and modifies an outgoing network request.
    ///
    /// - Parameter request: The original `InterceptorRequest` to be intercepted.
    /// - Returns: The modified `InterceptorRequest` after interception.
    func intercept(request: InterceptorRequest) async -> InterceptorRequest
    
    /// Intercepts and processes an incoming network response.
    ///
    /// - Parameter response: The original `InterceptorResponse` to be intercepted.
    /// - Returns: The modified `InterceptorResponse` after interception.
    func intercept(response: InterceptorResponse) async -> InterceptorResponse
    
    /// Creates the body data for a multipart form request before interception.
    ///
    /// - Parameters:
    ///   - multiparts: An array of `Part` objects representing the form data parts.
    ///   - boundary: The unique boundary string used to separate parts in the request.
    ///   - mimeType: The MIME type of the multipart data.
    /// - Returns: A `Data` object representing the properly formatted multipart form request body.
    func beforeInterceptionBodyCreatorFor(multiparts: [Part], boundary: String) -> Data

    /// Writes a multipart/form-data body directly to a temporary file instead of building it
    /// fully in memory, to avoid a large peak memory allocation when uploading big files (e.g.
    /// video/image parts).
    ///
    /// - Parameters:
    ///   - multiparts: An array of `Part` objects representing the form data parts.
    ///   - boundary: The unique boundary string used to separate parts in the request.
    /// - Returns: The URL of a temporary file containing the encoded body. `Network` deletes
    ///   this file once the request (including any retries) completes.
    func multipartBodyFileURL(multiparts: [Part], boundary: String) -> URL

    /// Sets up initial headers for a multipart request, adding a `Content-Type` if a boundary is provided.
    ///
    /// - Parameters:
    ///   - headers: A dictionary of existing HTTP headers.
    ///   - boundary: An optional boundary string for multipart form data.
    /// - Returns: A modified dictionary containing the necessary headers for a multipart request.
    func setupingInitialHeaders(_ headers: [String: String], boundary: String?) -> [String: String]
    
    // MARK: - Throwable APIs
    /// Intercepts throwable and modifies an outgoing network request.
    ///
    /// - Parameter request: The original `InterceptorRequest` to be intercepted.
    /// - Returns: The modified `InterceptorRequest` after interception.
    /// This api added to provided error handling for interception proccesses.
    func interceptThrowable(request: InterceptorRequest) async throws -> InterceptorRequest
    
    /// Intercepts throwable and modifies an incoming network response.
    ///
    /// - Parameter request: The original `InterceptorResponse` to be intercepted.
    /// - Returns: The modified `InterceptorResponse` after interception.
    /// This api added to provided error handling for interception proccesses.
    func interceptThrowable(response: InterceptorResponse) async throws -> InterceptorResponse

    /// Handles an authentication challenge presented by the underlying `URLSession` — e.g. for
    /// SSL/certificate pinning (`NSURLAuthenticationMethodServerTrust`), client certificate
    /// authentication, or Basic/NTLM credentials.
    ///
    /// - Parameter challenge: The challenge presented by the server.
    /// - Returns: The disposition to use, and a credential when the disposition requires one.
    func handle(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)
}

// MARK: - Default Implementation

public extension InterceptorProtocol {
    /// Default implementation of request interception, which returns the original request unchanged.
    ///
    /// - Parameter request: The original `InterceptorRequest` to be intercepted.
    /// - Returns: The original `InterceptorRequest`.
    func intercept(request: InterceptorRequest) async -> InterceptorRequest { request }
    
    /// Default implementation of response interception, which returns the original response unchanged.
    ///
    /// - Parameter response: The original `InterceptorResponse` to be intercepted.
    /// - Returns: The original `InterceptorResponse`.
    func intercept(response: InterceptorResponse) async -> InterceptorResponse { response }
    
    /// Default Implementaion of the body data for a multipart form request before interception.
    ///
    ///  - Parameters:
    ///     - mulriparts: An array containg the data parts.
    ///     - boundary: A UUID String representing the boundary.
    ///     - mimeType: The MIMEType of the data file.
    /// -   Returns: A `Data` object representing the properly formatted multipart form request body.
    func beforeInterceptionBodyCreatorFor(multiparts: [Part], boundary: String) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)"
        
        multiparts.forEach { aPart in
            body.append(boundaryPrefix)
            body.append("\r\n")
            if let filename = aPart.filename {
                body.append("Content-Disposition: form-data; name=\"\(aPart.name)\"; filename=\"\(filename)\"\r\n")
                if let mimeType = aPart.mimeType {
                    body.append("Content-Type: \(mimeType.mimeType ?? "")")
                }
            } else {
                let mimeType = aPart.mimeType ?? .text(subType: .plain(charset: .utf8))
                body.append("Content-Disposition: form-data; name=\"\(aPart.name)\"\r\n")
                body.append("Content-Type: \(mimeType.mimeType ?? "")")
            }
            
            body.append("\r\n")
            body.append("\r\n")
            
            if let value = aPart.value {
                body.append(value)
            }

            if let fileURL = aPart.bodyFileURL, let fileData = try? Data(contentsOf: fileURL) {
                body.append(fileData)
            } else if let data = aPart.body {
                body.append(data)
            }

            body.append("\r\n")
        }

        body.append(boundaryPrefix.appending("--"))

        return body
    }

    /// Default implementation, which streams each part's bytes straight to a temporary file
    /// rather than accumulating them into a single, potentially huge, in-memory `Data`.
    func multipartBodyFileURL(multiparts: [Part], boundary: String) -> URL {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else {
            // Fall back to the in-memory builder if the file couldn't be created.
            let data = beforeInterceptionBodyCreatorFor(multiparts: multiparts, boundary: boundary)
            try? data.write(to: fileURL)
            return fileURL
        }
        defer { try? fileHandle.close() }

        let boundaryPrefix = "--\(boundary)"

        func write(_ string: String) {
            guard let data = string.data(using: .utf8) else { return }
            fileHandle.write(data)
        }

        multiparts.forEach { aPart in
            write(boundaryPrefix)
            write("\r\n")
            if let filename = aPart.filename {
                write("Content-Disposition: form-data; name=\"\(aPart.name)\"; filename=\"\(filename)\"\r\n")
                if let mimeType = aPart.mimeType {
                    write("Content-Type: \(mimeType.mimeType ?? "")")
                }
            } else {
                let mimeType = aPart.mimeType ?? .text(subType: .plain(charset: .utf8))
                write("Content-Disposition: form-data; name=\"\(aPart.name)\"\r\n")
                write("Content-Type: \(mimeType.mimeType ?? "")")
            }

            write("\r\n\r\n")

            if let value = aPart.value {
                write(value)
            }

            if let sourceFileURL = aPart.bodyFileURL {
                fileHandle.writeContents(ofFileAt: sourceFileURL)
            } else if let data = aPart.body {
                fileHandle.write(data)
            }

            write("\r\n")
        }

        write(boundaryPrefix.appending("--"))

        return fileURL
    }

    func setupingInitialHeaders(_ headers: [String: String], boundary: String?) -> [String: String] {
        var headers = headers
        if let boundary {
            headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        }
        return headers
    }
    
    /// Default implementation of request interception, which returns the original request unchanged.
    ///
    /// - Parameter request: The original `InterceptorRequest` to be intercepted.
    /// - Returns: The original `InterceptorRequest`.
    func interceptThrowable(request: InterceptorRequest) async throws -> InterceptorRequest {
        request
    }
    
    /// Default implementation of response interception, which returns the original response unchanged.
    ///
    /// - Parameter response: The original `InterceptorResponse` to be intercepted.
    /// - Returns: The original `InterceptorResponse`.
    func interceptThrowable(response: InterceptorResponse) async throws -> InterceptorResponse {
        response
    }

    /// Default implementation of challenge handling, which performs the system's default handling
    /// (equivalent to not implementing a challenge handler at all).
    func handle(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
}

private extension FileHandle {
    /// Appends the contents of the file at `sourceURL`, reading it in bounded chunks rather than
    /// loading it into memory all at once — the point of `FilePart`/`bodyFileURL` for large files.
    func writeContents(ofFileAt sourceURL: URL) {
        guard let input = InputStream(url: sourceURL) else { return }
        input.open()
        defer { input.close() }

        let bufferSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while input.hasBytesAvailable {
            let bytesRead = input.read(&buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                write(Data(bytes: buffer, count: bytesRead))
            } else {
                break
            }
        }
    }
}
