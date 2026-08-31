import Foundation
import NZNetworkShared

extension NZDownloader {
    
    internal func proceedUploadDataTask(from dataBytes: Data, to path: Path, _ delegate: NZDownloaderUploadDelegate?) -> Int {

        // Background sessions only support upload tasks backed by a file, not an in-memory
        // Data blob, so transparently spill it to a temporary file and upload that instead.
        if isBackgroundSession {
            let temporaryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            do {
                try dataBytes.write(to: temporaryFileURL, options: .atomic)
            } catch {
                assertionFailure("NZDownload: Failed writing in-memory data to a temporary file for a background upload. error: \(error.localizedDescription)")
            }
            return proceedUploadDataTask(from: temporaryFileURL, to: path, delegate)
        }

        let request = createRequestForTask(with: path)
        let uploadTask: URLSessionUploadTask = session.uploadTask(with: request, from: dataBytes)
        
        let identifier: Int = uploadTask.taskIdentifier
        
        if let delegate {
            delegateForHandledTask[identifier] = delegate
        }
        
        uploadTask.resume()
        
        return identifier
    }
    
    internal func proceedUploadDataTask(from filePath: URL, to path: Path, _ delegate: NZDownloaderUploadDelegate?) -> Int {
        
        let request = createRequestForTask(with: path)
        let uploadTask: URLSessionUploadTask = session.uploadTask(with: request, fromFile: filePath)
        
        let identifier: Int = uploadTask.taskIdentifier
        
        if let delegate {
            delegateForHandledTask[identifier] = delegate
        }
        
        uploadTask.resume()
        
        return identifier
    }
    
    internal func proceedDownloadDataTask(from path: Path, _ delegate: NZDownloaderDownloadDelegate?) -> Int {
        
        let request = createRequestForTask(with: path)
        let downloadTask: URLSessionDownloadTask = session.downloadTask(with: request)
        
        let identifier: Int = downloadTask.taskIdentifier
        
        if let delegate {
            delegateForHandledTask[identifier] = delegate
        }
        
        downloadTask.resume()
        
        return identifier
    }
    
    internal func proceedDownloadDataTask(resuming data: Data, _ delegate: NZDownloaderDownloadDelegate?) -> Int {
        
        let downloadTask: URLSessionDownloadTask = session.downloadTask(withResumeData: data)
        
        let identifier: Int = downloadTask.taskIdentifier
        
        if let delegate {
            delegateForHandledTask[identifier] = delegate
        }
        
        downloadTask.resume()
        
        return identifier
    }
}

fileprivate extension NZDownloader {
    
    func createRequestForTask(with path: Path) -> URLRequest {
        
        let url = URL(baseEndPoint: baseURL, route: path.route, queryItems: path.queryItems)
        
        let request = URLRequest(url: url, cachePolicy: session.configuration.requestCachePolicy, timeoutInterval: timeout)
        return request
    }
}
