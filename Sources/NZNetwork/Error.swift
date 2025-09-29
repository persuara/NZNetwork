import Foundation

public enum NetworkError: Error {
    case localError(Error)
    case remoteError(Data)
}

/// Extension on `Error` to provide access to specific `NetworkError` details.
public extension Error {

    /// Extracts the data associated with a remote error, if the error is of type `NetworkError.remoteError`.
    ///
    /// - Returns: The `Data` object from the remote error, or `nil` if the error is not a `NetworkError.remoteError`.
    ///
    /// This property allows you to retrieve the response data from a network request that failed due to a server-side issue.
    /// The data can be useful for debugging or further analysis of the server's response.
    var remoteErrorData: Data? {
        guard let networkError = self as? NetworkError,
              case .remoteError(let data) = networkError else {
            return nil
        }
        return data
    }
    
    /// Extracts the underlying local error, if the error is of type `NetworkError.localError`.
    ///
    /// - Returns: The `Error` object associated with the local error, or `nil` if the error is not a `NetworkError.localError`.
    ///
    /// This property provides access to the underlying local error (such as connectivity issues or encoding failures)
    /// when a network request fails due to a client-side issue.
    var localError: Error? {
        guard let networkError = self as? NetworkError,
              case .localError(let error) = networkError else {
            return nil
        }
        return error
    }
}
