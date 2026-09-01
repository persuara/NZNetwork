# Network

[![CI](https://github.com/sacondeinc/networkiOS/actions/workflows/ci.yml/badge.svg)](https://github.com/sacondeinc/networkiOS/actions/workflows/ci.yml)

A lightweight, protocol-oriented networking framework for iOS built on `URLSession` and Swift concurrency (`async`/`await`). It provides a small, composable core for REST-style requests (`NZNetwork`), a dedicated file downloader/uploader with progress tracking (`NZDownload`), and shared URL/URLRequest helpers (`NZNetworkShared`).

## Requirements

- iOS 13.0+
- Swift 5.5+ (uses `async`/`await`)

## Installation — Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/persuara/network.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the repository URL.

The library product is called `NZNetwork` and bundles five targets: `NZNetwork` (requests), `NZDownload` (downloads/uploads), `NZSocket` (WebSockets), `NZReachability` (network status monitoring), and `NZNetworkShared` (types used across the others, like `NetworkSessionConfiguration` and `CertificatePinning`). Import whichever you need — `NZNetworkShared` is a dependency of the other four, but its own public types (unlike `NZNetwork`'s etc.) aren't automatically visible unless you import it directly too:

```swift
import NZNetwork
import NZDownload
import NZSocket
import NZReachability
import NZNetworkShared
```

## Package structure

| Module | Purpose |
|---|---|
| `NZNetwork` | GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS requests, multipart bodies, request/response interception, retries, cancellation, logging, error handling |
| `NZDownload` | Background-friendly file downloads and uploads with progress/pause/resume/cancel |
| `NZSocket` | WebSocket connections with an `async` message stream and connect/disconnect delegate events |
| `NZReachability` | Online/offline and connection-type monitoring via `NWPathMonitor` |
| `NZNetworkShared` | Internal helpers (`URL`/`URLRequest`/`Data` extensions) shared by all modules |

## Running tests

```bash
xcodebuild test -scheme NZNetwork -destination 'platform=iOS Simulator,name=iPhone 17'
```

(Swap in whatever simulator name you have installed.) CI runs the same command — plus a plain `build` — on every push and pull request to `main` via [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Test targets: `NZNetworkSharedTests` (URL/`URLRequest` construction, `NetworkSessionConfiguration`), `NZNetworkTests` (`RetryPolicy`, `FormBody`, `MIMEType`, multipart/`FilePart` body building, streaming responses, and end-to-end `Network` request/retry/cancellation behavior via a stub `URLProtocol`), and `NZSocketTests` (`NZSocketReconnectPolicy`, message bridging).

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

`InterceptorProtocol` also has a `handle(challenge:)` method for responding to authentication challenges from the underlying `URLSession` — SSL/certificate pinning, client certificate authentication, or Basic/NTLM credentials. The default implementation performs the system's default handling (unchanged behavior if you don't override it). For certificate pinning specifically, use the built-in `CertificatePinning` helper instead of writing `SecTrust` comparison code by hand:

```swift
import NZNetworkShared   // CertificatePinning lives here

final class AppInterceptor: InterceptorProtocol {
    // ...

    private let pinning = CertificatePinning(pinnedHashes: [
        "k3XT+2e2Nq3s+E2/w7wKKVArgOJ/HydIQNfEmoWDA/o="   // base64 SHA-256 of the pinned key's SPKI
    ])

    func handle(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        pinning.evaluate(challenge) ?? (.performDefaultHandling, nil)
    }
}
```

`CertificatePinning` pins against the Subject Public Key Info (SPKI) of the server's certificate chain — the approach OWASP recommends, since it survives certificate renewal as long as the key doesn't change. `evaluate(_:)` returns `nil` for non-server-trust challenges (so you can fall through to your own handling for client certs, Basic/NTLM, etc.), `.useCredential` if the chain is both system-trusted and contains a pinned key, or `.cancelAuthenticationChallenge` otherwise. Generate a pin hash with:

```bash
openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
```

`InterceptorProtocol` also has a `redirect(from:to:)` method for handling HTTP redirects (3xx responses) — e.g. to strip an `Authorization` header before following a redirect to a different host, or to prevent the redirect entirely. The default follows every redirect unchanged:

```swift
final class AppInterceptor: InterceptorProtocol {
    // ...

    func redirect(from response: HTTPURLResponse, to newRequest: URLRequest) async -> URLRequest? {
        guard newRequest.url?.host == response.url?.host else {
            var sameOriginOnlyRequest = newRequest
            sameOriginOnlyRequest.setValue(nil, forHTTPHeaderField: "Authorization")
            return sameOriginOnlyRequest
        }
        return newRequest   // same host — follow as-is
    }
}
```

Return `nil` to stop following the redirect and treat the redirect response itself as final. `NZDownloaderDelegate.downloader(_:willPerformRedirect:to:)` and `NZSocketDelegate.socket(_:willPerformRedirect:to:)` work the same way for `NZDownload`/`NZSocket`.

### 1.2 Create a `Network` instance

```swift
let network = Network(interceptor: AppInterceptor())
```

Keep it around (e.g. as a singleton or injected dependency) — it owns the underlying `URLSession`.

Optionally, pass a `RetryPolicy` to automatically retry requests that come back with a retryable status code (`429`, `500`, `502`, `503`, `504` by default), using exponential backoff:

```swift
let network = Network(interceptor: AppInterceptor(), retryPolicy: RetryPolicy(maxAttempts: 3))

// Fully customized:
let network = Network(
    interceptor: AppInterceptor(),
    retryPolicy: RetryPolicy(
        maxAttempts: 4,
        retryableStatusCodes: [429, 503],
        backoff: { attempt in Double(attempt) * 0.5 }   // 0.5s, 1s, 1.5s, ...
    )
)
```

No `retryPolicy` argument (or `.none`) disables retries — the default, unchanged behavior. Retries only apply to non-2xx server responses; transport failures (no connection, DNS errors, timeouts) and cancellations are never retried automatically — handle those yourself in the interceptor if you need to.

You can also pass a `NetworkSessionConfiguration` to control session-wide behavior — caching, cellular/expensive-network access, and whether requests wait for connectivity instead of failing immediately:

```swift
let network = Network(
    interceptor: AppInterceptor(),
    sessionConfiguration: NetworkSessionConfiguration(
        cachePolicy: .useProtocolCachePolicy,   // opt into standard HTTP caching (default: no caching)
        urlCache: URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024),
        allowsCellularAccess: true,
        allowsExpensiveNetworkAccess: true,
        allowsConstrainedNetworkAccess: true,
        waitsForConnectivity: true
    )
)
```

Every field has a default matching this framework's historical behavior (no caching, all network types allowed, doesn't wait for connectivity), so omitting `sessionConfiguration` entirely keeps existing code working unchanged. `NetworkSessionConfiguration` is shared by `Network`, `NZDownloader`, and `NZSocket` — same shape, same knobs, wherever you use it.

Finally, pass a `logger: NetworkLogger` to observe every request/response — useful for debugging without entangling logging with your interceptor's actual request/response transformation logic:

```swift
let network = Network(interceptor: AppInterceptor(), logger: ConsoleNetworkLogger(level: .body))
```

`ConsoleNetworkLogger` ships with three levels (`.basic`, `.headers`, `.body`) and prints to the console. Bring your own `NetworkLogger` conformance to pipe into `os_log`, a crash reporter's breadcrumbs, or anything else:

```swift
struct OSLogNetworkLogger: NetworkLogger {
    func log(request: InterceptorRequest) {
        os_log("→ %{public}@ %{public}@", request.method.rawValue, request.url.absoluteString)
    }
    func log(response: InterceptorResponse, data: Data) {
        os_log("← %d %{public}@", response.statusCode, response.request.url.absoluteString)
    }
    func log(error: Error, for request: InterceptorRequest) {
        os_log("✗ %{public}@ %{public}@", request.url.absoluteString, error.localizedDescription)
    }
}
```

`log(response:data:)` fires once per actual HTTP round trip — including once per automatic retry — after interception, so it reflects what was actually sent/received on the wire. No `logger` argument (the default) logs nothing, same as before this feature existed.

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

Available methods on both APIs: `get`, `post(payload:)`, `put(payload:)`, `patch(payload:)`, `delete`, `delete(body:)`, `head`, `options`, plus `...Throwable` equivalents (`getThrowable`, `postThrowable`, `putThrowable`, `patchThrowable`, `deleteThrowable`, `headThrowable`, `optionsThrowable`).

#### Typed decoding sugar

If you'd rather not call `JSONDecoder().decode(_:from:)` manually at every call site, a `...Decoded` variant of each `...Throwable` method decodes the JSON response for you:

```swift
struct User: Decodable { let id: Int; let name: String }

let user: User = try await network.getDecoded(path: Path(route: "/users/1", queryItems: nil))
let created: User = try await network.postDecoded(path: Path(route: "/users", queryItems: nil), payload: NewUser(name: "Ada"))
```

Available: `getDecoded`, `postDecoded(payload:)`, `putDecoded(payload:)`, `patchDecoded(payload:)`, `deleteDecoded`, each taking an optional `decoder: JSONDecoder` (defaults to a plain `JSONDecoder()`). Decoding failures throw the raw `DecodingError`, same as encoding failures already do on the `...Throwable` methods — they aren't wrapped in `NetworkError`.

### 1.4 Per-request timeout and cache policy

`Path` accepts an optional `timeout`, which overrides the interceptor's default `timeout` for just that one request:

```swift
let result = await network.get(path: Path(route: "/slow-endpoint", queryItems: nil, timeout: 60))
```

It also accepts an optional `cachePolicy`, which overrides `Network`'s session-wide cache policy (see §1.2) for just that one request:

```swift
let result = await network.get(path: Path(route: "/live-price", queryItems: nil, cachePolicy: .reloadIgnoringLocalCacheData))
```

Omit either (the default) to fall back to the interceptor's timeout / the session's cache policy, as before.

### 1.5 Cancelling a request

There are two ways to cancel a request.

**Wrap it in a `Task`** — every `Network` method is `async`, so the idiomatic Swift concurrency approach is to cancel the enclosing `Task`; cancellation propagates straight through to the underlying `URLSessionTask`:

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

**Or use the `...Cancellable` handle API** if you'd rather not manage your own `Task`. It returns a `NetworkTask` handle immediately, so you can hold onto it (e.g. as a property) and cancel it from anywhere, then await the result separately:

```swift
let request = network.getCancellable(path: Path(route: "/users", queryItems: nil))
self.currentRequest = request   // hang onto it so you can cancel later

Task {
    let result = await request.result
    // ...
}

// later:
self.currentRequest?.cancel()
```

Also available: `postCancellable(path:payload:)`, `putCancellable(path:payload:)`, `patchCancellable(path:payload:)`, `deleteCancellable(path:)`, `deleteCancellable(path:body:)`.

### 1.6 Multipart requests

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

The framework builds the `multipart/form-data` body and `Content-Type` boundary header for you. To keep large uploads (photos, videos) from spiking memory, the body is streamed from a temporary file rather than assembled into one large in-memory `Data` — the file is written incrementally and deleted automatically once the request (and any retries) finishes.

That avoids the extra full-body copy, but a `Part` whose `body` is `Data` still requires that data to be fully loaded into memory by whoever constructs the part. For a genuinely huge single file, use `FilePart` instead — it streams straight from disk in bounded chunks, so the file's bytes are never held in memory all at once:

```swift
let result = await network.post(
    path: Path(route: "/videos", queryItems: nil),
    multipart: FilePart(name: "video", fileURL: localVideoFileURL)
)
```

`FilePart` infers `filename` and `mimeType` from the file URL if you don't pass them explicitly. You can also add `bodyFileURL` to your own custom `Part` conformances instead of using `FilePart` — it's a protocol requirement with a default of `nil`, so existing conformances are unaffected, and when set it takes precedence over `body`.

### 1.7 `application/x-www-form-urlencoded` requests

For endpoints expecting classic HTML-form bodies instead of JSON or multipart, use `FormBody`:

```swift
let result = await network.postForm(
    path: Path(route: "/oauth/token", queryItems: nil),
    form: FormBody(["grant_type": "password", "username": "ada", "password": "secret"])
)

// Order-preserving, if the server cares about field order:
let data = try await network.postFormThrowable(
    path: Path(route: "/oauth/token", queryItems: nil),
    form: FormBody([URLQueryItem(name: "grant_type", value: "password"), URLQueryItem(name: "username", value: "ada")])
)
```

`FormBody` percent-encodes the fields and sets `Content-Type: application/x-www-form-urlencoded; charset=utf-8` for you. Available: `postForm`/`postFormThrowable`, `putForm`/`putFormThrowable`, `patchForm`/`patchFormThrowable`.

### 1.8 `MIMEType`

A typed representation of common MIME types, used for multipart parts:

```swift
MIMEType.image(subtype: .png)
MIMEType.document(subtype: .pdf)
MIMEType.text(subType: .plain(charset: .utf8))
MIMEType.sniff(fileExtension: "jpg")   // -> .image(subtype: .jpeg)
MIMEType(mimeType: "application/custom+type")
```

### 1.9 Streaming responses

_Requires iOS 15+._ `get`/`getThrowable` buffer the entire response body before returning it. For Server-Sent Events, newline-delimited JSON, or any endpoint where you want to start processing data as it arrives, use `stream`/`streamLines` instead:

```swift
// Raw byte chunks
for try await chunk in network.stream(path: Path(route: "/events", queryItems: nil)) {
    // process each chunk as it arrives
}

// Text lines — convenient for SSE ("data: ..." frames) or NDJSON
for try await line in network.streamLines(path: Path(route: "/events", queryItems: nil)) {
    print(line)
}
```

Both are GET-only, and a non-2xx status code throws `NetworkError.remoteError` before any chunk is yielded. Neither participates in `RetryPolicy` — retrying mid-stream isn't meaningful — and neither is exposed on `NetworkProtocol`, since it's an `@available(iOS 15.0, *)` addition and the protocol itself has no minimum-OS gate. `stream(path:chunkSize:)` takes an optional `chunkSize` (default 16 KB) controlling how many bytes it buffers before yielding.

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

Set `downloader.delegate` (`NZDownloaderDelegate`) to be notified if the underlying `URLSession` becomes invalid, or to handle authentication challenges (SSL pinning, client certificates, Basic/NTLM) via `downloader(_:didReceive:)` — same shape as `InterceptorProtocol.handle(challenge:)` in §1.1, defaulting to the system's default handling if you don't override it.

Pass a `sessionConfiguration: NetworkSessionConfiguration` to `NZDownloader`'s initializer for cellular access, connectivity waiting, etc. — same type used by `Network` (see §1.2). Its default preserves `NZDownloader`'s historical behavior (standard HTTP caching, all network types allowed).

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

#### JSON convenience

If your server exchanges JSON, skip the manual `Encodable`/`Decodable` juggling:

```swift
struct ChatMessage: Codable { let text: String }

try await socket.send(ChatMessage(text: "hello"))   // encodes and sends as a .string message

Task {
    for try await message: ChatMessage in socket.messages() {
        print(message.text)
    }
}
```

`send<T: Encodable>(_:encoder:)` and `messages<T: Decodable>(decoder:) -> AsyncThrowingStream<T, Error>` are built on top of the raw `.string`/`.data` API — the generic `messages()` overload is resolved by the type annotation on the `for try await` loop. It's subject to the same "call once per connection" rule as the raw `messages()`, since it's implemented on top of it.

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

All delegate methods have default no-op implementations (or, for `didReceive challenge:`, the system's default handling), so you only implement what you need. `socket.isConnected` reflects the current connection state at any time. There's also `socket(_:willReconnectAttempt:after:)`, covered next.

`NZSocket`'s initializer also accepts a `sessionConfiguration: NetworkSessionConfiguration` for cellular access, connectivity waiting, etc. — same type used by `Network`/`NZDownloader` (see §1.2).

### 3.5 Auto-reconnect

By default, if the connection drops unexpectedly (not from an explicit `disconnect()` call), the `messages()` stream just finishes or throws — you'd have to detect that and call `connect(to:protocols:)` again yourself. Pass a `reconnectPolicy: NZSocketReconnectPolicy` to have `NZSocket` do that automatically, with backoff:

```swift
let socket = NZSocket(baseURL: "api.example.com", reconnectPolicy: NZSocketReconnectPolicy(maxAttempts: 5))

// Fully customized:
let socket = NZSocket(
    baseURL: "api.example.com",
    reconnectPolicy: NZSocketReconnectPolicy(
        maxAttempts: 10,
        backoff: { attempt in Double(attempt) * 2 }   // 2s, 4s, 6s, ...
    )
)
```

While auto-reconnect is in effect, an existing `for try await message in socket.messages()` loop keeps running transparently — the stream doesn't finish on a drop that's about to be retried, only once reconnect attempts are exhausted (or the policy is `.none`, the default) or you call `disconnect()` yourself. `socket(_:willReconnectAttempt:after:)` fires on your delegate before each attempt, if you want to show connecting UI. The reconnect attempt counter resets to zero after each successful reconnection.

### 3.6 Heartbeat / keep-alive

`sendPing()` exists, but nothing calls it periodically for you by default. Pass a `heartbeatInterval` to have `NZSocket` send a ping automatically on a schedule while connected:

```swift
let socket = NZSocket(baseURL: "api.example.com", heartbeatInterval: 30)   // ping every 30s
```

The heartbeat starts on a successful connection and stops on disconnect (whether explicit or unexpected). Omit `heartbeatInterval` (the default, `nil`) to disable it — same as before this feature existed.

---

## 4. `NZReachability` — network status monitoring

`NZReachability` wraps Apple's `NWPathMonitor` to tell you whether the device is online, and over what kind of connection — useful for showing an offline banner, gating expensive requests on Wi-Fi, or deciding whether to bother retrying at all.

### 4.1 Start monitoring

```swift
import NZReachability

let reachability = NZReachability()
reachability.start()

print(reachability.isConnected)        // Bool
print(reachability.currentStatus)      // NZReachabilityStatus?, nil until the first update arrives
```

Call `reachability.stop()` when you're done (e.g. in `deinit`) to stop the underlying monitor and finish any active `statusUpdates()` stream.

### 4.2 Observe changes

Either via an `AsyncStream`:

```swift
Task {
    for await status in reachability.statusUpdates() {
        print("Connected: \(status.isConnected), via: \(status.connectionType)")
    }
}
```

Or via a delegate:

```swift
final class ConnectivityHandler: NZReachabilityDelegate {
    func reachability(_ reachability: NZReachabilityProtocol, didUpdateStatus status: NZReachabilityStatus) {
        print("Connected: \(status.isConnected), via: \(status.connectionType)")
    }
}

reachability.delegate = ConnectivityHandler()
```

`NZReachabilityStatus` also exposes `isExpensive` (cellular/personal hotspot) and `isConstrained` (Low Data Mode), and `NZConnectionType` distinguishes `.wifi`, `.cellular`, `.wiredEthernet`, `.other`, and `.unavailable`. Pass a `requiredInterfaceType` to `NZReachability`'s initializer to monitor a single interface type instead of all of them (e.g. Wi-Fi-only reachability).

---

## 5. Error handling reference

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
