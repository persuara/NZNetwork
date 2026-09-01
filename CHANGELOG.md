# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.11.0] - 2026-09-01

### Added
- `InterceptorProtocol.redirect(from:to:)`, `NZDownloaderDelegate.downloader(_:willPerformRedirect:to:)`, and `NZSocketDelegate.socket(_:willPerformRedirect:to:)` — inspect, modify, or cancel HTTP redirects (3xx responses), e.g. to strip an `Authorization` header before following a redirect to a different host. Mirrors the existing `handle(challenge:)` pattern; defaults to following every redirect unchanged.
- `CertificatePinning` (`NZNetworkShared`) — pins against SPKI SHA-256 hashes (the OWASP-recommended, renewal-friendly approach) for RSA 2048/4096 and EC P-256/P-384 keys, plugging directly into `handle(challenge:)` instead of requiring hand-written `SecTrust` comparison code.

## [1.10.0] - 2026-09-01

### Added
- `Network.stream(path:chunkSize:)` and `streamLines(path:)` — stream the response body incrementally via `URLSession.bytes(for:)` instead of buffering the whole thing, for Server-Sent Events, newline-delimited JSON, or any endpoint where processing should start before the response finishes. `@available(iOS 15.0, *)`, since `bytes(for:)` (unlike `data(for:)`) isn't backported to iOS 13; GET-only, run through the interceptor for headers/auth, throw `NetworkError.remoteError` on a non-2xx status before any chunk is yielded, and don't participate in `RetryPolicy`.
- `CHANGELOG.md`, covering all releases back to 1.0.0.

## [1.9.0] - 2026-09-01

### Added
- `FilePart` — a ready-to-use `Part` backed by a file on disk, inferring `filename`/`mimeType` from the file URL when not given explicitly.
- `Part.bodyFileURL` (optional, defaults to `nil`, so existing conformances are unaffected). The streamed multipart body builder reads it via `InputStream` in bounded 64KB chunks straight into the destination temp file, instead of loading the source file into memory first — closing the residual memory gap for genuinely huge single-file uploads that temp-file streaming (1.5.0) didn't cover.

## [1.8.0] - 2026-09-01

### Added
- A test suite: `NZNetworkSharedTests`, `NZNetworkTests` (including an end-to-end `Network` integration suite via a stub `URLProtocol`), and `NZSocketTests`.
- GitHub Actions CI, running build + test on every push/PR to `main`.
- `Locked<Value>`, a lock-protected box for state genuinely mutated from more than one thread.

### Fixed
- `MIMEType.custom(mimeType:)` producing a doubled mime string (e.g. `"application/json/application/json"`) — it used `Substring.base`, which returns the substring's original full string, not its own text.
- `URL(baseEndPoint:route:queryItems:)` producing a double slash (`https://api.example.com//users`) whenever `route` started with `/` — how virtually every example in the README calls it.
- Real data races found while auditing for Swift 6 / strict-concurrency readiness: a plain `lazy var session` in `Network`/`NZDownloader`/`NZSocket` wasn't thread-safe; `NZDownloader`'s task-delegate dictionary and `backgroundCompletionHandler`, `NZSocket`'s connection state, and `NZReachability`'s `currentStatus`/`continuation` were all mutated from both a caller's thread and a `URLSession`/`NWPathMonitor` delegate queue. All now lock-protected.

### Changed
- `Network`, `NZDownloader`, `NZSocket`, and `NZReachability` are now `@unchecked Sendable` (honestly, now that the races above are fixed); `NetworkTask`, `NetworkResult`, `RetryPolicy`, `NZSocketReconnectPolicy`, `NZSocketMessage`, `NZSocketError`, `NZReachabilityStatus`, and `NZConnectionType` are `Sendable`.

## [1.7.0] - 2026-09-01

### Added
- `NZSocketReconnectPolicy` (max attempts + backoff) drives automatic reconnection on `NZSocket` after an unexpected disconnect. The `messages()` stream stays alive across the reconnect instead of finishing, so an existing consumer loop keeps receiving messages transparently. `socket(_:willReconnectAttempt:after:)` notifies the delegate before each attempt.
- `heartbeatInterval` starts a background loop calling `sendPing()` on a schedule while connected, stopping on any disconnect.
- `send<T: Encodable>(_:encoder:)` and `messages<T: Decodable>(decoder:)` — JSON convenience on top of the existing raw `.string`/`.data` API.

All additive and default to off, so existing consumers see no behavior change.

## [1.6.0] - 2026-09-01

### Added
- `NZReachability` module, wrapping `NWPathMonitor` to expose online/offline state and connection type (`wifi`/`cellular`/`wiredEthernet`/`other`/`unavailable`) via a delegate (`NZReachabilityDelegate`) and an `AsyncStream` (`statusUpdates()`), plus `isExpensive`/`isConstrained` flags.
- `NetworkLogger`, a request/response logging hook independent of `InterceptorProtocol`, wired into `Network(...:logger:)` and firing once per actual HTTP round trip (including retries). Ships with `ConsoleNetworkLogger` (`.basic`/`.headers`/`.body` levels).

Both additive and default to off/`nil`, so existing consumers see no behavior change.

## [1.5.0] - 2026-09-01

### Added
- Streamed multipart bodies: `InterceptorProtocol.multipartBodyFileURL(multiparts:boundary:)` writes parts straight to a temporary file instead of building the whole body as one in-memory `Data`, avoiding a memory spike on large uploads. The request pipeline streams that file via `URLRequest.httpBodyStream` and deletes it once the request (including retries) finishes.
- `FormBody`, adding `application/x-www-form-urlencoded` support, exposed as `postForm`/`putForm`/`patchForm` and their `Throwable` variants, alongside the existing JSON (`Encodable`) and multipart request bodies.
- Typed decoding sugar: `getDecoded`/`postDecoded`/`putDecoded`/`patchDecoded`/`deleteDecoded` decode the JSON response as `T: Decodable` directly, on top of the existing `...Throwable` methods.

All additive and backward-compatible; existing call sites are unaffected.

## [1.4.0] - 2026-09-01

### Added
- `NetworkSessionConfiguration` (shared via `NZNetworkShared`), exposing `cachePolicy`, `urlCache`, `allowsCellularAccess`, `allowsExpensiveNetworkAccess`, `allowsConstrainedNetworkAccess`, and `waitsForConnectivity`, via a new `sessionConfiguration` parameter on `Network`, `NZDownloader`, and `NZSocket`.
- `Path` (`NZNetwork`) now also accepts a per-request `cachePolicy` override.
- `Network`, `NZDownloader`, and `NZSocket` now conform to `URLSessionDelegate` and forward authentication challenges (SSL/certificate pinning, client certificates, Basic/NTLM) to `InterceptorProtocol.handle(challenge:)`, `NZDownloaderDelegate.downloader(_:didReceive:)`, and `NZSocketDelegate.socket(_:didReceive:)` respectively.

All defaults preserve each type's prior behavior exactly, so existing callers are unaffected.

## [1.3.0] - 2026-09-01

### Added
- `NetworkTask` + `...Cancellable` methods (`getCancellable`, `postCancellable`, `putCancellable`, `patchCancellable`, `deleteCancellable`) let you cancel an in-flight request via a handle, without managing your own `Task`.
- `RetryPolicy`, adding opt-in automatic retries with exponential backoff for retryable HTTP status codes, via `Network(interceptor:retryPolicy:)`.
- `Path` now accepts an optional `timeout` that overrides the interceptor's default for a single request.
- `patch`/`head`/`options` and their `Throwable` variants, alongside the existing `get`/`post`/`put`/`delete`.

## [1.2.0] - 2026-09-01

### Added
- Cancelling the enclosing `Task` now surfaces as `NetworkResult.cancelled` (or `CancellationError` on the throwable API) instead of a generic local error.
- `NZDownloader` accepts a `backgroundSessionIdentifier` so transfers keep running while the app is suspended or terminated.
- In-memory uploads are transparently spilled to a temp file for background sessions, since those only support file-backed uploads.
- `backgroundCompletionHandler` wires `NZDownloader` up to `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.

## [1.1.0] - 2026-09-01

### Added
- `NZSocket` module, wrapping `URLSessionWebSocketTask` for WebSocket connections.
- `connect(to:protocols:)` opens a connection, upgrading `https` to `wss`.
- `messages()` exposes incoming messages as an `AsyncThrowingStream` you can `for try await` over.
- `send(_:)` and `sendPing()` for outgoing string/data messages and keep-alive pings.
- `NZSocketDelegate` reports connect/disconnect lifecycle events; `isConnected` reflects the current connection state.

## [1.0.0] - 2025-09-29

### Added
- `NZNetwork`: GET/POST/PUT/DELETE requests with `async`/`await`, plus a throwable (`...Throwable`) variant of each.
- Multipart form-data support via the `Part` protocol.
- Request/response interception via `InterceptorProtocol`, for auth headers, logging, and transparent retry (`.proceed(request:)`).
- Typed `MIMEType` representation for multipart bodies.
- `NZDownload`: file upload/download tasks with progress tracking, pause/resume/cancel, and resumable downloads via resume data.

[1.11.0]: https://github.com/persuara/network/compare/1.10.0...1.11.0
[1.10.0]: https://github.com/persuara/network/compare/1.9.0...1.10.0
[1.9.0]: https://github.com/persuara/network/compare/1.8.0...1.9.0
[1.8.0]: https://github.com/persuara/network/compare/1.7.0...1.8.0
[1.7.0]: https://github.com/persuara/network/compare/1.6.0...1.7.0
[1.6.0]: https://github.com/persuara/network/compare/1.5.0...1.6.0
[1.5.0]: https://github.com/persuara/network/compare/1.4.0...1.5.0
[1.4.0]: https://github.com/persuara/network/compare/1.3.0...1.4.0
[1.3.0]: https://github.com/persuara/network/compare/1.2.0...1.3.0
[1.2.0]: https://github.com/persuara/network/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/persuara/network/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/persuara/network/releases/tag/1.0.0
