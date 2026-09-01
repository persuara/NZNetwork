import Foundation

extension NZDownloader: URLSessionDownloadDelegate {
    
    // MARK: URLSessionDownloadDelegate
    
    /// Tells the delegate that a download task has finished downloading.
    /// - Parameters:
    ///   - session: The session containing the download task that finished.
    ///   - downloadTask: The download task that finished.
    ///   - location: A file URL for the temporary file. Because the file is temporary, you must either open the file for reading or move it to a permanent location in your app’s sandbox container directory before returning from this delegate method.
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let identifier = downloadTask.taskIdentifier
        
        if let delegate = delegateForHandledTask[identifier] as? NZDownloaderDownloadDelegate {
            delegate.downloader(self, downloadTask: identifier, didFinishDownloadingTo: location)
            
            // TODO: MIGHT HAVE TO MOVE IT TO A NEW TEMPORARY PLACE SO IT CAN BE MOVED LATER.
        }
    }
    
    /// Periodically informs the delegate about the download’s progress.
    /// - Parameters:
    ///   - session: The session containing the download task.
    ///   - downloadTask: The download task.
    ///   - bytesWritten: The number of bytes transferred since the last time this delegate method was called.
    ///   - totalBytesWritten: The total number of bytes transferred so far.
    ///   - totalBytesExpectedToWrite: The expected length of the file, as provided by the Content-Length header. If this header was not provided, the value is NSURLSessionTransferSizeUnknown.
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let identifier = downloadTask.taskIdentifier
        
        if let delegate = delegateForHandledTask[identifier] as? NZDownloaderDownloadDelegate {
            
            if (totalBytesExpectedToWrite == 0) || (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) { return } // Divide by Zero
            let percentage: Float = (Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)) * 100
            
            delegate.downloader(self, downloadTask: identifier, didReceiveProgress: percentage)
        }
    }
    
    /// Tells the delegate that the download task has resumed downloading.
    /// - Parameters:
    ///   - session: The session containing the download task that finished.
    ///   - downloadTask: The download task that resumed. See explanation in the discussion.
    ///   - fileOffset: If the file's cache policy or last modified date prevents reuse of the existing content, then this value is zero. Otherwise, this value is an integer representing the number of bytes on disk that do not need to be retrieved again.
    ///   - expectedTotalBytes: The expected length of the file, as provided by the Content-Length header. If this header was not provided, the value is NSURLSessionTransferSizeUnknown.
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        let identifier = downloadTask.taskIdentifier
        
        if let delegate = delegateForHandledTask[identifier] as? NZDownloaderDownloadDelegate {
            
            if expectedTotalBytes == 0 || expectedTotalBytes == NSURLSessionTransferSizeUnknown { return } // Divide by Zero
            let percentage: Float = (Float(fileOffset) / Float(expectedTotalBytes)) * 100
            
            delegate.downloader(self, downloadTask: identifier, didResumeAtOffset: percentage)
        }
    }
    
    // MARK: URLSessionTaskDelegate
    
    /// Tells the delegate that a new task was created.
    ///
    /// - Parameters:
    ///   - session: The URL session that created the task.
    ///   - task: The newly created task.
    @available(iOS 16.0, *)
    open func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let identifier = task.taskIdentifier
        
        if let delegate = delegateForHandledTask[identifier] {
            delegate.downloader(self, didCreateTask: identifier)
        }
    }
    
    /// This method is called when a background session task with a delayed start time (as set with the earliestBeginDate property) is ready to start. This delegate method should only be implemented if the request might become stale while waiting for the network load and needs to be replaced by a new request.
    /// For loading to continue, the delegate must call the completion handler, passing in a disposition that indicates how the task should proceed. Passing the URLSession.DelayedRequestDisposition.cancel disposition is equivalent to calling cancel() on the task directly.
    ///
    /// - Parameters:
    ///   - session: The session containing the delayed request.
    ///   - task: The task handling the delayed request.
    ///   - request: The request that was delayed.
    ///   - completionHandler: A completion handler to perform the request. The completion handler takes two parameters: a disposition that tells the task how to proceed, and a new request object that is only used if the disposition is URLSession.DelayedRequestDisposition.useNewRequest.
    open func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping @Sendable (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        let identifier = task.taskIdentifier
        
        let disposition: URLSession.DelayedRequestDisposition = .continueLoading
        
        if let delegate = delegateForHandledTask[identifier] {
            delegate.downloader(self, task: identifier, willBeginDelayedRequestWith: disposition)
        }
        
        completionHandler(disposition, request)
    }
    
    
    /// This method is called if the waitsForConnectivity property of URLSessionConfiguration is true, and sufficient connectivity is unavailable. The delegate can use this opportunity to update the user interface; for example, by presenting an offline mode or a cellular-only mode.
    /// This method is called, at most, once per task, and only if connectivity is initially unavailable. It is never called for background sessions because waitsForConnectivity is ignored for those sessions.
    /// - Parameters:
    ///   - session: The session that contains the waiting task.
    ///   - task: The task that is waiting for a change in connectivity.
    open func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        let identifier = task.taskIdentifier
        
        if let delegate = delegateForHandledTask[identifier] {
            delegate.downloader(self, taskIsWaitingForConnectivityWith: identifier)
        }
    }
    
    /// The totalBytesSent and totalBytesExpectedToSend parameters are also available as URLSessionTask properties countOfBytesSent and countOfBytesExpectedToSend. Or, since URLSessionTask supports ProgressReporting, you can use the task’s progress property instead, which may be more convenient.
    ///
    /// - Parameters:
    ///   - session: The session containing the data task.
    ///   - task: The data task.
    ///   - bytesSent: The number of bytes sent since the last time this delegate method was called.
    ///   - totalBytesSent: The total number of bytes sent so far.
    ///   - totalBytesExpectedToSend: The expected length of the body data. The URL loading system can determine the length of the upload data in three ways:
    ///
    /// - From the length of the NSData object provided as the upload body.
    ///
    /// - From the length of the file on disk provided as the upload body of an upload task (not a download task).
    ///
    /// - From the Content-Length in the request object, if you explicitly set it.
    ///
    /// Otherwise, the value is NSURLSessionTransferSizeUnknown (-1) if you provided a stream or body data object, or zero (0) if you did not.
    open func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let identifier = task.taskIdentifier
        
        if let delegate = delegateForHandledTask[identifier] as? NZDownloaderUploadDelegate {
            
            if (totalBytesExpectedToSend == 0) || (totalBytesExpectedToSend == NSURLSessionTransferSizeUnknown) { return } // Divide by Zero
            let percentage: Float = (Float(totalBytesSent) / Float(totalBytesExpectedToSend)) * 100
            
            delegate.downloader(self, uploadTask: identifier, didReceiveProgress: percentage)
        }
    }
    
    /// Tells the delegate that the session finished collecting metrics for the task.
    ///
    /// - Parameters:
    ///   - session: The session collecting the metrics.
    ///   - task: The task whose metrics have been collected.
    ///   - metrics: The collected metrics.
    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let identifier = task.taskIdentifier
        
        if let delegate = delegateForHandledTask[identifier] {
            delegate.downloader(self, didFinishCollecting: metrics, forTaskWith: identifier)
        }
    }
    
    /// The only errors your delegate receives through the error parameter are client-side errors, such as being unable to resolve the hostname or connect to the host. To check for server-side errors, inspect the response property of the task parameter received by this callback.
    ///
    /// - Parameters:
    ///   - session: The session containing the task that has finished transferring data.
    ///   - task: The task that has finished transferring data.
    ///   - error: If an error occurred, an error object indicating how the transfer failed, otherwise NULL.
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let identifier = task.taskIdentifier
        
        // Upload
        if let delegate = delegateForHandledTask[identifier] {
            if let error {
                delegate.downloader(self, didCompleteTask: identifier, with: error)
            } else {
                delegate.downloaderCompletedTask(self, with: identifier)
            }
        }
    }
    
    // MARK: URLSessionDelegate
    
    /// If you invalidate a session by calling its finishTasksAndInvalidate() method, the session waits until after the final task in the session finishes or fails before calling this delegate method. If you call the invalidateAndCancel() method, the session calls this delegate method immediately.
    /// - Parameters:
    ///   - session: The session object that was invalidated.
    ///   - error: The error that caused invalidation, or nil if the invalidation was explicit.
    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {

        if let delegate = delegate {
            delegate.downloader(self, session, didBecomeInvalidWithError: error)
        }
    }

    /// Forwards session-wide authentication challenges (SSL pinning, client certificates,
    /// Basic/NTLM credentials, ...) to `delegate.downloader(_:didReceive:)`.
    open func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let delegate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        Task {
            let (disposition, credential) = await delegate.downloader(self, didReceive: challenge)
            completionHandler(disposition, credential)
        }
    }

    /// Forwards HTTP redirects to `delegate.downloader(_:willPerformRedirect:to:)`.
    open func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let delegate else {
            completionHandler(request)
            return
        }
        Task {
            let redirectRequest = await delegate.downloader(self, willPerformRedirect: response, to: request)
            completionHandler(redirectRequest)
        }
    }

    /// Tells the delegate that all messages enqueued for a background session have been delivered.
    ///
    /// Call this from `application(_:handleEventsForBackgroundURLSession:completionHandler:)` by
    /// storing the system's completion handler in `backgroundCompletionHandler` — it is invoked
    /// (and cleared) here, once the session has finished replaying its queued events.
    /// - Parameter session: The background session that finished delivering its events.
    open func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }
}
