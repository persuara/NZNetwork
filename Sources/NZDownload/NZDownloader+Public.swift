import Foundation
import NZNetworkShared

extension NZDownloader: NZDownloaderProtocol {
    
    @discardableResult
    public func upload(from data: Data, to path: Path, delegate: NZDownloaderUploadDelegate?) -> Int {
        proceedUploadDataTask(from: data, to: path, delegate)
    }
    
    @discardableResult
    public func upload(fromFile filePath: URL, to path: Path, delegate: NZDownloaderUploadDelegate?) -> Int {
        proceedUploadDataTask(from: filePath, to: path, delegate)
    }
    
    @discardableResult
    public func download(from path: Path, delegate: NZDownloaderDownloadDelegate?) -> Int {
        proceedDownloadDataTask(from: path, delegate)
    }
    
    @discardableResult
    public func download(resumingFrom dataByte: Data, delegate: NZDownloaderDownloadDelegate?) -> Int {
        proceedDownloadDataTask(resuming: dataByte, delegate)
    }
}

extension NZDownloader: NZDownloaderTaskProtocol {
    
    @discardableResult
    public func cancel(identifier: Int) async -> Bool {
        
        if let aTask = await findTaskFor(identifier: identifier) {
            aTask.cancel()
            return true
        }
        return false
    }
    
    @discardableResult
    public func pause(identifier: Int) async -> Bool {
        
        if let aTask = await findTaskFor(identifier: identifier) {
            aTask.suspend()
            return true
        }
        return false
    }
    
    @discardableResult
    public func resume(identifier: Int) async -> Bool {
        
        if let aTask = await findTaskFor(identifier: identifier) {
            aTask.resume()
            return true
        }
        return false
    }
    
    @discardableResult
    public func cancelDownloadTask(with identifier: Int) async -> Data? {
        
        if let aTask = await findTaskFor(identifier: identifier) as? URLSessionDownloadTask {
            let data = await aTask.cancelByProducingResumeData()
            return data
        }
        return nil
    }
    
    private func findTaskFor(identifier: Int) async -> URLSessionTask? {
        let allTasks = await session.allTasks
        return allTasks.first(where: { $0.taskIdentifier == identifier })
    }
}
