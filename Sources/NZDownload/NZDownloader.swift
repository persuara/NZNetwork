import Foundation
import NZNetworkShared

/// A protocol that defines methods for handling downloading and uploading tasks.
public protocol NZDownloaderProtocol {
    
    /// Uploads data to a specified path with optional delegate for tracking progress.
    ///
    /// - Parameters:
    ///   - data: The data to be uploaded.
    ///   - path: The destination path for the upload.
    ///   - delegate: An optional delegate to track upload progress.
    /// - Returns: A per-session unique task identifier for the upload task.
    @discardableResult
    func upload(from data: Data, to path: Path, delegate: NZDownloaderUploadDelegate?) -> Int
    
    /// Uploads data from a file URL to a specified path with optional delegate for tracking progress.
    ///
    /// - Parameters:
    ///   - filePath: The URL of the file to be uploaded.
    ///   - path: The destination path for the upload.
    ///   - delegate: An optional delegate to track upload progress.
    /// - Returns: A per-session unique task identifier for the upload task.
    @discardableResult
    func upload(fromFile filePath: URL, to path: Path, delegate: NZDownloaderUploadDelegate?) -> Int
    
    /// Downloads data from a specified path with optional delegate for tracking progress.
    ///
    /// - Parameters:
    ///   - path: The source path to download from.
    ///   - delegate: An optional delegate to track download progress.
    /// - Returns: A per-session unique task identifier for the download task.
    @discardableResult
    func download(from path: Path, delegate: NZDownloaderDownloadDelegate?) -> Int
    
    /// Resumes a download task from a specific data byte with optional delegate for tracking progress.
    ///
    /// - Parameters:
    ///   - dataByte: The data byte from which to resume the download.
    ///   - delegate: An optional delegate to track download progress.
    /// - Returns: A per-session unique task identifier for the download task.
    @discardableResult
    func download(resumingFrom dataByte: Data, delegate: NZDownloaderDownloadDelegate?) -> Int
}

/// A protocol that defines methods for managing downloader tasks.
public protocol NZDownloaderTaskProtocol {
    
    /// Cancels a downloader task with the specified identifier.
    ///
    /// - Parameters:
    ///   - identifier: The unique identifier of the task to cancel.
    /// - Returns: A boolean value indicating whether the cancellation was successful.
    @discardableResult
    func cancel(identifier: Int) async -> Bool
    
    /// Pauses a downloader task with the specified identifier.
    ///
    /// - Parameters:
    ///   - identifier: The unique identifier of the task to pause.
    /// - Returns: A boolean value indicating whether the pause was successful.
    @discardableResult
    func pause(identifier: Int) async -> Bool
    
    /// Resumes a paused downloader task with the specified identifier.
    ///
    /// - Parameters:
    ///   - identifier: The unique identifier of the task to resume.
    /// - Returns: A boolean value indicating whether the resumption was successful.
    @discardableResult
    func resume(identifier: Int) async -> Bool
    
    /// Cancels a download task with the specified identifier and returns the downloaded data.
    ///
    /// - Parameters:
    ///   - identifier: The unique identifier of the task to cancel.
    /// - Returns: The downloaded data if available, or nil.
    @discardableResult
    func cancelDownloadTask(with identifier: Int) async -> Data?
}

/// A protocol that defines methods for the downloader delegate.
public protocol NZDownloaderDelegate: NSObjectProtocol {
    
    /// Tells the delegate that the session has become invalid.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - session: The session that became invalid.
    ///   - error: An optional error indicating the cause of invalidation.
    func downloader(_ downloader: NZDownloaderProtocol, _ session: URLSession, didBecomeInvalidWithError: Error?)

    /// Handles an authentication challenge presented by the underlying `URLSession` — e.g. for
    /// SSL/certificate pinning, client certificate authentication, or Basic/NTLM credentials.
    ///
    /// - Parameter challenge: The challenge presented by the server.
    /// - Returns: The disposition to use, and a credential when the disposition requires one.
    func downloader(_ downloader: NZDownloaderProtocol, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)
}

public extension NZDownloaderDelegate {
    /// Default implementation, which performs the system's default handling.
    func downloader(_ downloader: NZDownloaderProtocol, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
}

/// A protocol that defines methods for task-related delegate callbacks.
public protocol NZDownloaderTaskDelegate {
    
    /// Informs the delegate that a new task has been created.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - identifier: The unique identifier of the created task.
    @available(iOS 16.0, *)
    func downloader(_ downloader: NZDownloaderProtocol, didCreateTask identifier: Int)
    
    /// Informs the delegate that a task has been completed.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - identifier: The unique identifier of the completed task.
    func downloaderCompletedTask(_ downloader: NZDownloaderProtocol, with identifier: Int)
    
    /// Informs the delegate that a task has been completed with an error.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - identifier: The unique identifier of the completed task.
    ///   - error: The error associated with the completed task.
    func downloader(_ downloader: NZDownloaderProtocol, didCompleteTask identifier: Int, with error: Error)
    
    /// Informs the delegate that a task is about to begin a delayed request.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - identifier: The unique identifier of the task.
    ///   - disposition: The disposition of the delayed request.
    func downloader(_ downloader: NZDownloaderProtocol, task identifier: Int, willBeginDelayedRequestWith disposition: URLSession.DelayedRequestDisposition)
    
    /// Informs the delegate that a task is waiting for network connectivity.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - identifier: The unique identifier of the task.
    func downloader(_ downloader: NZDownloaderProtocol, taskIsWaitingForConnectivityWith identifier: Int)
    
    /// Informs the delegate that task metrics have been collected.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - metrics: The collected metrics for the task.
    ///   - identifier: The unique identifier of the task.
    func downloader(_ downloader: NZDownloaderProtocol, didFinishCollecting metrics: URLSessionTaskMetrics, forTaskWith identifier: Int)
}

/// A protocol that defines methods for the upload delegate.
public protocol NZDownloaderUploadDelegate: NZDownloaderTaskDelegate {
    
    /// Informs the delegate that an upload task has received progress.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - uploadTask: The unique identifier of the upload task.
    ///   - percentage: The progress percentage.
    func downloader(_ downloader: NZDownloaderProtocol, uploadTask: Int, didReceiveProgress percentage: Float)
}

/// A protocol that defines methods for the download delegate.
public protocol NZDownloaderDownloadDelegate: NZDownloaderTaskDelegate {
    
    /// Informs the delegate that a download task has finished downloading.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - downloadTask: The unique identifier of the download task.
    ///   - location: The temporary location where the downloaded file is stored.
    func downloader(_ downloader: NZDownloaderProtocol, downloadTask: Int, didFinishDownloadingTo location: URL)
    
    /// Informs the delegate that a paused download task has resumed.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - downloadTask: The unique identifier of the download task.
    ///   - percentage: The progress percentage of the resumed download.
    func downloader(_ downloader: NZDownloaderProtocol, downloadTask: Int, didResumeAtOffset percentage: Float)
    
    /// Informs the delegate that a download task has received progress.
    ///
    /// - Parameters:
    ///   - downloader: The downloader instance.
    ///   - downloadTask: The unique identifier of the download task.
    ///   - percentage: The progress percentage.
    func downloader(_ downloader: NZDownloaderProtocol, downloadTask: Int, didReceiveProgress percentage: Float)
}

/// A struct representing a path for network requests.
public struct Path {

    /// The route for the network request.
    ///
    /// Example: "/category"
    public let route: String

    /// Optional query items to include in the request.
    ///
    /// Example: [URLQueryItem(name: "id", value: "1")]
    public let queryItems: [URLQueryItem]?
    
    public init(route: String, queryItems: [URLQueryItem]?) {
        self.route = route
        self.queryItems = queryItems
    }
}

/// A class that provides functionality for downloading and uploading tasks.
public class NZDownloader: NSObject {
    
    /// The delegate for the NZDownloader.
    weak public var delegate: NZDownloaderDelegate?
    
    /// Dictionary that holds task delegates for handling specific tasks.
    internal var delegateForHandledTask: [Int: NZDownloaderTaskDelegate] = [:]
    
    /// The base URL used for constructing URLs for network requests.
    internal let baseURL: String
    
    /// The timeout interval for network requests.
    internal let timeout: TimeInterval

    /// The identifier used to run this downloader's session in the background, if any.
    ///
    /// When set, transfers continue while the app is suspended or terminated, and the system
    /// relaunches the app to deliver events. Must be unique per app and stable across launches.
    internal let backgroundSessionIdentifier: String?

    /// `true` when this downloader was configured with a `backgroundSessionIdentifier`.
    public var isBackgroundSession: Bool { backgroundSessionIdentifier != nil }

    /// The completion handler provided by the system via
    /// `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    ///
    /// Set this from your `UIApplicationDelegate`/`UISceneDelegate` when the app is relaunched to
    /// handle background transfer events; it is called (and cleared) once all queued delegate
    /// callbacks for the background session have been delivered.
    public var backgroundCompletionHandler: (() -> Void)?

    /// Session-level behavior such as cellular access and connectivity waiting.
    internal let sessionConfiguration: NetworkSessionConfiguration

    /// Initializes a new instance of NZDownloader.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL used for constructing URLs for network requests.
    ///   - timeout: The timeout interval for network requests (default is 10 seconds).
    ///   - backgroundSessionIdentifier: When provided, the downloader uses a background
    ///     `URLSession` so uploads/downloads can continue while the app is suspended or
    ///     terminated. Must be unique per app and stable across launches (default is `nil`,
    ///     meaning a regular foreground session is used).
    ///   - sessionConfiguration: Session-level behavior such as cellular access and connectivity waiting.
    ///     Defaults to `.useProtocolCachePolicy` caching (this class's historical behavior), unlike
    ///     `Network`'s `.default`, which disables caching.
    public init(baseURL: String, timeout: TimeInterval = 10, backgroundSessionIdentifier: String? = nil, sessionConfiguration: NetworkSessionConfiguration = NetworkSessionConfiguration(cachePolicy: .useProtocolCachePolicy)) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.backgroundSessionIdentifier = backgroundSessionIdentifier
        self.sessionConfiguration = sessionConfiguration

        super.init()
    }

    /// The URLSession used for network requests.
    internal lazy var session: URLSession = {
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()

    /// The URLSessionConfiguration used for configuring the session.
    private lazy var configuration: URLSessionConfiguration = {
        let configuration: URLSessionConfiguration
        if let backgroundSessionIdentifier {
            configuration = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
            configuration.sessionSendsLaunchEvents = true
        } else {
            configuration = .default
        }
        sessionConfiguration.apply(to: configuration)
        return configuration
    }()
}
