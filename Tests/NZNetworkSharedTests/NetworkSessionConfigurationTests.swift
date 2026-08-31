import XCTest
@testable import NZNetworkShared

final class NetworkSessionConfigurationTests: XCTestCase {

    func testDefaultPreservesHistoricalNoCachingBehavior() {
        let configuration = URLSessionConfiguration.default
        NetworkSessionConfiguration.default.apply(to: configuration)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
    }

    func testAppliesCustomValues() {
        let sessionConfiguration = NetworkSessionConfiguration(
            cachePolicy: .useProtocolCachePolicy,
            allowsCellularAccess: false,
            allowsExpensiveNetworkAccess: false,
            allowsConstrainedNetworkAccess: false,
            waitsForConnectivity: true
        )
        let configuration = URLSessionConfiguration.default
        sessionConfiguration.apply(to: configuration)

        XCTAssertEqual(configuration.requestCachePolicy, .useProtocolCachePolicy)
        XCTAssertFalse(configuration.allowsCellularAccess)
        XCTAssertFalse(configuration.allowsExpensiveNetworkAccess)
        XCTAssertFalse(configuration.allowsConstrainedNetworkAccess)
        XCTAssertTrue(configuration.waitsForConnectivity)
    }

    func testCustomURLCacheIsAppliedWhenProvided() {
        let cache = URLCache(memoryCapacity: 1024, diskCapacity: 1024)
        let sessionConfiguration = NetworkSessionConfiguration(urlCache: cache)
        let configuration = URLSessionConfiguration.default
        sessionConfiguration.apply(to: configuration)
        XCTAssertTrue(configuration.urlCache === cache)
    }

    func testProtocolClassesAreInstalledWhenProvided() {
        final class DummyProtocol: URLProtocol {}
        let sessionConfiguration = NetworkSessionConfiguration(protocolClasses: [DummyProtocol.self])
        let configuration = URLSessionConfiguration.default
        sessionConfiguration.apply(to: configuration)
        XCTAssertTrue(configuration.protocolClasses?.contains { $0 == DummyProtocol.self } ?? false)
    }

    func testNilURLCacheLeavesExistingCacheUntouched() {
        let existingCache = URLCache(memoryCapacity: 1024, diskCapacity: 1024)
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = existingCache

        NetworkSessionConfiguration.default.apply(to: configuration)

        XCTAssertTrue(configuration.urlCache === existingCache)
    }
}
