import Foundation

/// A lock-protected box for state that's genuinely mutated from more than one thread — typically
/// a caller's thread racing against a `URLSession` delegate queue. Not a general-purpose
/// concurrency primitive; just enough to make this package's `@unchecked Sendable` classes
/// actually thread-safe rather than merely silencing the compiler.
public final class Locked<Value>: @unchecked Sendable {

    private let lock = NSLock()
    private var value: Value

    public init(_ value: Value) {
        self.value = value
    }

    /// Reads the current value.
    public func get() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    /// Overwrites the current value.
    public func set(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }

    /// Reads and/or mutates the value atomically, returning whatever `body` returns.
    @discardableResult
    public func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
