# Network

A lightweight, protocol-oriented networking framework for iOS built on `URLSession` and Swift concurrency (`async`/`await`). It provides a small, composable core for REST-style requests (`NZNetwork`), a dedicated file downloader/uploader with progress tracking (`NZDownload`), and shared URL/URLRequest helpers (`NZNetworkShared`).

## Requirements

- iOS 13.0+
- Swift 5.5+ (uses `async`/`await`)

## Installation — Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sacondeinc/networkiOS.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the repository URL.

The library product is called `NZNetwork` and bundles three targets: `NZNetwork` (requests), `NZDownload` (downloads/uploads), and `NZSocket` (WebSockets). Import whichever you need:

```swift
import NZNetwork
import NZDownload
import NZSocket
```

## Package structure

| Module | Purpose |
|---|---|
| `NZNetwork` | GET/POST/PUT/DELETE requests, multipart bodies, request/response interception, error handling |
| `NZDownload` | Background-friendly file downloads and uploads with progress/pause/resume/cancel |
| `NZSocket` | WebSocket connections with an `async` message stream and connect/disconnect delegate events |
| `NZNetworkShared` | Internal helpers (`URL`/`URLRequest`/`Data` extensions) shared by all modules |

---

## 1. `NZNetwork` — making requests

### 1.1 Implement an `Interceptor`

Every request goes through an object conforming to `InterceptorProtocol`. This is where you configure the base URL, timeout, and any per-request logic (auth headers, logging, token refresh, retry, etc.). All methods have default (pass-through) implementations, so you only override what you need.

```swift
import NZNetwork

final class AppInterceptor: InterceptorProtocol {

    let baseURL = "api.example.com"
    let timeout: TimeInterval = 15

    // Attach headers/auth before the request is sent
    func intercept(request: InterceptorRequest) async -> InterceptorRequest {
        var request = request
        request.headers["Authorization"] = "Bearer \(TokenStore.shared.accessToken)"
        return request
    }

    // Inspect/transform the response, or transparently retry the request
    func intercept(response: InterceptorResponse) async -> InterceptorResponse {
        if response.statusCode == 401 {
            // e.g. refresh the token, then replay the original request
            var retriedRequest = response.request
            retriedRequest.headers["Authorization"] = "Bearer \(TokenStore.shared.refreshedToken())"
            return InterceptorResponse(
                request: response.request,
                localizedMessageForStatusCode: response.localizedMessageForStatusCode,
                statusCode: response.statusCode,
                headers: response.headers,
                result: .proceed(request: retriedRequest)
            )
        }
        return response
    }
}
```

`InterceptorResponse.Result` controls what happens next:

- `.response(data:)` — hand the (possibly modified) data back as the result.
- `.error(error:)` — fail the request with a local error.
- `.close` — cancel the request.
- `.proceed(request:)` — resend a (possibly modified) request, e.g. after a token refresh.

### 1.2 Create a `Network` instance

```swift
let network = Network(interceptor: AppInterceptor())
```

Keep it around (e.g. as a singleton or injected dependency) — it owns the underlying `URLSession`.

### 1.3 Perform requests

`Network` exposes two parallel API styles: a **result-based** API (`NetworkResult`) and a **throwing** API (`...Throwable`). Use whichever fits your call site.

#### Result-based API

```swift
let result = await network.get(path: Path(route: "/users", queryItems: [URLQueryItem(name: "page", value: "1")]))

switch result {
case .success(let data):
    let users = try? JSONDecoder().decode([User].self, from: data)
case .remoteError(let data):
    // Non-2xx status code; `data` is the server's error body
    break
case .localError(let error):
    // Connectivity/encoding/etc. failure
    break
case .cancelled:
    break
}
```

```swift
struct NewUser: Encodable { let name: String }

let result = await network.post(path: Path(route: "/users", queryItems: nil), payload: NewUser(name: "Ada"))
```

#### Throwing API

```swift
do {
    let data = try await network.getThrowable(path: Path(route: "/users", queryItems: nil))
    let users = try JSONDecoder().decode([User].self, from: data)
} catch {
    // Non-2xx responses surface as NetworkError.remoteError(Data)
    // Local/connectivity failures surface as NetworkError.localError(Error)
    if let responseData = error.remoteErrorData {
        // inspect the server's error payload
    } else if let underlying = error.localError {
        // inspect the underlying local error
    }
}
```

Available methods on both APIs: `get`, `post(payload:)`, `put(payload:)`, `delete`, `delete(body:)`, plus `...Throwable` equivalents (`getThrowable`, `postThrowable`, `putThrowable`, `deleteThrowable`).

### 1.4 Cancelling a request

Every `Network` method is `async`, so the idiomatic way to cancel one is to wrap the call in a Swift `Task` and cancel that task — cancellation propagates straight through to the underlying `URLSessionTask`:

```swift
let task = Task {
    await network.get(path: Path(route: "/users", queryItems: nil))
}

// later, e.g. when the user navigates away
task.cancel()

let result = await task.value
if case .cancelled = result {
    // the request never completed
}
```

The throwing API surfaces the same event as a `CancellationError` instead:

```swift
let task = Task {
    try await network.getThrowable(path: Path(route: "/users", queryItems: nil))
}
task.cancel()

do {
    _ = try await task.value
} catch is CancellationError {
    // the request never completed
}
```

### 1.5 Multipart requests

Define your form fields by conforming to `Part`:

```swift
struct ImagePart: Part {
    let name = "avatar"
    let filename: String? = "avatar.jpg"
    let body: Data?
    let value: String? = nil
    let mimeType: MIMEType? = .image(subtype: .jpeg)
}

struct TextField: Part {
    let name: String
    let filename: String? = nil
    let body: Data? = nil
    let value: String?
    let mimeType: MIMEType? = nil
}
```

Then send them as a `POST` or `PUT`, either as variadic arguments or an array:

```swift
let result = await network.post(
    path: Path(route: "/profile", queryItems: nil),
    multipart: ImagePart(body: imageData), TextField(name: "bio", value: "Hello!")
)

// or

let parts: [Part] = [ImagePart(body: imageData), TextField(name: "bio", value: "Hello!")]
let data = try await network.postThrowable(path: Path(route: "/profile", queryItems: nil), multipart: parts)
```

The framework builds the `multipart/form-data` body and `Content-Type` boundary header for you.

### 1.6 `MIMEType`

A typed representation of common MIME types, used for multipart parts:

```swift
MIMEType.image(subtype: .png)
MIMEType.document(subtype: .pdf)
MIMEType.text(subType: .plain(charset: .utf8))
MIMEType.sniff(fileExtension: "jpg")   // -> .image(subtype: .jpeg)
MIMEType(mimeType: "application/custom+type")
```

---

## 2. `NZDownload` — downloading & uploading files

`NZDownloader` wraps a delegate-based `URLSession` for large transfers, exposing progress, pause/resume, and cancellation. Unlike `Network`, it's delegate-driven rather than `async`-return-driven, since progress needs to stream over time.

### 2.1 Create a downloader

```swift
import NZDownload

let downloader = NZDownloader(baseURL: "api.example.com", timeout: 30)
```

### 2.2 Download a file

```swift
final class DownloadHandler: NSObject, NZDownloaderDownloadDelegate {
    func downloader(_ downloader: NZDownloaderProtocol, downloadTask: Int, didReceiveProgress percentage: Float) {
        print("Progress: \(percentage)%")
    }
    func downloader(_ downloader: NZDownloaderProtocol, downloadTask: Int, didFinishDownloadingTo location: URL) {
        // Move the file out of the temporary location before returning
    }
    func downloader(_ downloader: NZDownloaderProtocol, downloadTask: Int, didResumeAtOffset percentage: Float) {}
    func downloaderCompletedTask(_ downloader: NZDownloaderProtocol, with identifier: Int) {}
    func downloader(_ downloader: NZDownloaderProtocol, didCompleteTask identifier: Int, with error: Error) {}
    @available(iOS 16.0, *)
    func downloader(_ downloader: NZDownloaderProtocol, didCreateTask identifier: Int) {}
    func downloader(_ downloader: NZDownloaderProtocol, task identifier: Int, willBeginDelayedRequestWith disposition: URLSession.DelayedRequestDisposition) {}
    func downloader(_ downloader: NZDownloaderProtocol, taskIsWaitingForConnectivityWith identifier: Int) {}
    func downloader(_ downloader: NZDownloaderProtocol, didFinishCollecting metrics: URLSessionTaskMetrics, forTaskWith identifier: Int) {}
}

let handler = DownloadHandler()
let taskID = downloader.download(from: Path(route: "/files/report.pdf", queryItems: nil), delegate: handler)
```

Every call returns an `Int` task identifier you use later to control that specific transfer:

```swift
await downloader.pause(identifier: taskID)
await downloader.resume(identifier: taskID)
await downloader.cancel(identifier: taskID)

// Cancel but keep resumable data for later:
if let resumeData = await downloader.cancelDownloadTask(with: taskID) {
    downloader.download(resumingFrom: resumeData, delegate: handler)
}
```

### 2.3 Upload a file

```swift
// From in-memory data
let taskID = downloader.upload(from: fileData, to: Path(route: "/upload", queryItems: nil), delegate: uploadHandler)

// From a file on disk
let taskID = downloader.upload(fromFile: fileURL, to: Path(route: "/upload", queryItems: nil), delegate: uploadHandler)
```

Implement `NZDownloaderUploadDelegate` (adds `didReceiveProgress` for uploads) the same way as the download delegate above.

### 2.4 Session-level events

Set `downloader.delegate` (`NZDownloaderDelegate`) to be notified if the underlying `URLSession` becomes invalid.

### 2.5 Background sessions

Pass a `backgroundSessionIdentifier` to run transfers on a background `URLSession`, so downloads and uploads keep going while your app is suspended or terminated, and the system relaunches it to deliver progress/completion events:

```swift
let downloader = NZDownloader(
    baseURL: "api.example.com",
    timeout: 30,
    backgroundSessionIdentifier: "com.yourapp.downloader.background"
)
```

The identifier must be unique to your app and stable across launches. Everything from §2.2–2.3 works unchanged — `download`/`upload` still return a task identifier, and delegate callbacks still fire the same way. One difference: background sessions can't upload an in-memory `Data` blob directly (only file-backed uploads and downloads are supported), so `upload(from data:to:delegate:)` transparently writes the data to a temporary file first when `downloader.isBackgroundSession` is `true` — you don't need to do anything differently.

Wire the app back up to the session in your `UIApplicationDelegate`:

```swift
func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
) {
    // `downloader` must be the same instance (same backgroundSessionIdentifier) used to start the transfer.
    downloader.backgroundCompletionHandler = completionHandler
}
```

`NZDownloader` calls that stored handler for you once the session has finished replaying all of its queued events.

---

## 3. `NZSocket` — WebSocket connections

`NZSocket` wraps `URLSessionWebSocketTask`. Incoming messages are exposed as an `AsyncThrowingStream` so you can `for await` over them; connect/disconnect lifecycle events are reported through a delegate, similar to `NZDownload`.

### 3.1 Create a socket and connect

```swift
import NZSocket

let socket = NZSocket(baseURL: "api.example.com", timeout: 15)
socket.connect(to: Path(route: "/chat"), protocols: [])
```

`connect(to:protocols:)` builds the URL the same way `Network`/`NZDownloader` do (`https` is upgraded to `wss` automatically by `URLSession`), then opens the connection.

### 3.2 Receive messages

```swift
Task {
    do {
        for try await message in socket.messages() {
            switch message {
            case .string(let text):
                print("Received: \(text)")
            case .data(let data):
                print("Received \(data.count) bytes")
            }
        }
        print("Connection closed")
    } catch {
        print("Connection failed: \(error)")
    }
}
```

Call `messages()` once per connection — it returns the same live stream regardless of when you start iterating it.

### 3.3 Send messages and manage the connection

```swift
try await socket.send(.string("hello"))
try await socket.send(.data(payloadData))

try await socket.sendPing()          // keep-alive

socket.disconnect(closeCode: .normalClosure, reason: nil)
```

`send`/`sendPing` throw `NZSocketError.notConnected` if called before `connect(to:protocols:)` or after the connection has closed.

### 3.4 Lifecycle delegate

```swift
final class ChatSocketHandler: NZSocketDelegate {
    func socket(_ socket: NZSocketProtocol, didConnectWithProtocol protocol: String?) {
        print("Connected")
    }
    func socket(_ socket: NZSocketProtocol, didDisconnectWithCode code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Disconnected: \(code)")
    }
}

socket.delegate = ChatSocketHandler()
```

Both delegate methods have default no-op implementations, so you only implement what you need. `socket.isConnected` reflects the current connection state at any time.

---

## 4. Error handling reference

- `NetworkResult` — used by the non-throwing `Network` API: `.success`, `.remoteError`, `.localError`, `.cancelled`.
- `NetworkError` — thrown by the `...Throwable` API: `.remoteError(Data)`, `.localError(Error)`. Use the `Error.remoteErrorData` / `Error.localError` convenience properties to unwrap without a `switch`.

Both paths route through your `Interceptor`'s `intercept(response:)` / `interceptThrowable(response:)`, so centralized error handling (e.g. mapping status codes to app-specific errors, triggering a token refresh) belongs there.

---

## Conventional Commits

- For each Merge Request, all commits must adhere to the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) spec.
- Whenever possible, use a module name as a scope (e.g. `fix(service): Fix ProfileResponse issue.`).
- Use a proper sentence as a description — start with an uppercase letter, end with a dot.

### Allowed commit types

- `build`: Changes that affect build system (e.g. Gradle update)
- `chore`: Changes other than source or test code (e.g. library version updates)
- `ci`: CI configuration
- `docs`: Documentation changes
- `feat`: A new feature
- `fix`: Bug fixes
- `i18n`: Internationalization and translations
- `perf`: Performance Improvements
- `refactor`: A change in the source code that neither fixes a bug nor adds a feature
- `revert`: Reverting a commit
- `style`: Code style changes, not affecting code meaning (formatting)
- `test`: Adding new tests or improving existing ones
- `theme`: Changes related to UI theming
