import XCTest
import Security
@testable import NZNetworkShared

final class CertificatePinningTests: XCTestCase {

    // Self-signed RSA-2048 test certificate (CN=test.example.com), generated with:
    //   openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 1 -nodes -subj "/CN=test.example.com"
    // Expected SPKI SHA-256 hash computed independently via:
    //   openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
    private static let rsaCertificateDER = "MIIDFzCCAf+gAwIBAgIUDpFiXxjAycDu+DRuzOnSlQzS584wDQYJKoZIhvcNAQELBQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLmNvbTAeFw0yNjA5MDEwMDEwNTFaFw0yNjA5MDIwMDEwNTFaMBsxGTAXBgNVBAMMEHRlc3QuZXhhbXBsZS5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCVEc5nFAYYDXGvoqS2AFAu+SRYeq9R0B8d9LkqbI2SzpygoOMGGfUs++oTlm8QNa2S2mrY4PzM2IPTrrKsUj8neCfyf24F46yu91nGsXqXWjlHRjKIGOnwJcYSAjT/FVl1/NElMjmO9o25cyQ4VxGrwTTN76+S61P5nL+SNq+x+nfjBK98UAaC2kXcc7iwftkhBXUVuurR6QZhI5AeFOeDc6cE0/46cQW1DmIfAvosX6ywMe9xtpjjkIH1ibXl7Y6zdzDumwfhS2ubmt9dSpT4XNCO7XGaALqsoH+zwiH+nYeeZJ/DyFsiEp12QUG9yzWOgeIrcBXQh1XBje/Us+rHAgMBAAGjUzBRMB0GA1UdDgQWBBRaInytcgt9uJHgceEcLw17nNBJbjAfBgNVHSMEGDAWgBRaInytcgt9uJHgceEcLw17nNBJbjAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQABVJDMtoiJxgq8STUUP8eH/hKwd9Ag+0AjdnVIRTuEtLXYPukZPxCHOoeWc2dYXFXR6x2znQ/P7QqKjhUxcsoD7ampRuN2t+d84KlAJa06c7RUrExjABnpl3JrGm7U1jiPibUdG79TxuWzbJHhrnSbx725xnI2FPsTEDIhVFDvR9BiAlr0ta9awTl2dVGyclaP7nwJYGnhACkmm61ioRJKbrkQvPchhx7xMIH/qaK/XcT8GML56ZrPDpQMEmAukjKKlEX5L7Kuucnzv5uCwrCDnGF1DNzG+8pphc+TEzlrEcW7dykCgiYILEgPGC64cEJnL7zmqeQVaUYmsCIz0IE3"
    private static let rsaExpectedSPKIHash = "q4/+7LJoGstoKzSWmBt23afl/zSVc8VOF/WXhkGAIoQ="

    // Self-signed EC P-256 test certificate (CN=ec.example.com), generated the same way with
    // `openssl ecparam -name prime256v1` in place of `rsa:2048`.
    private static let ecCertificateDER = "MIIBhjCCAS2gAwIBAgIUS182u9eK2mk0P91cqmP5qOJIm+YwCgYIKoZIzj0EAwIwGTEXMBUGA1UEAwwOZWMuZXhhbXBsZS5jb20wHhcNMjYwOTAxMDAxMDU4WhcNMjYwOTAyMDAxMDU4WjAZMRcwFQYDVQQDDA5lYy5leGFtcGxlLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJZ8cJMmBzXwpYpDKK7Qgyht8io5V9VamG9P1fp5W7or9gLEzP0NLxxjRjAZwj+Hzam6SXE6P9wvqLeGzME+GJWjUzBRMB0GA1UdDgQWBBT4j2OQZPeEBgKR2JeThPTxTjFbGzAfBgNVHSMEGDAWgBT4j2OQZPeEBgKR2JeThPTxTjFbGzAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0cAMEQCIF1Rj5ZxXFQQdyWuWPVNDM9hB1Uj1DjNcznyzf2bHlRbAiA90qLX8iUNrpipXAfoN2IfiS6/0XBqDSqkR6hzGw1wJQ=="
    private static let ecExpectedSPKIHash = "tAnq01OERdK4U0QbHnMyYDmn8mR94zZZ4xRKreZ9EV4="

    private func certificate(fromDERBase64 base64: String) throws -> SecCertificate {
        let data = try XCTUnwrap(Data(base64Encoded: base64))
        return try XCTUnwrap(SecCertificateCreateWithData(nil, data as CFData))
    }

    func testRSASPKIHashMatchesIndependentlyComputedValue() throws {
        let certificate = try certificate(fromDERBase64: Self.rsaCertificateDER)
        XCTAssertEqual(CertificatePinning.spkiSHA256Hash(for: certificate), Self.rsaExpectedSPKIHash)
    }

    func testECSPKIHashMatchesIndependentlyComputedValue() throws {
        let certificate = try certificate(fromDERBase64: Self.ecCertificateDER)
        XCTAssertEqual(CertificatePinning.spkiSHA256Hash(for: certificate), Self.ecExpectedSPKIHash)
    }

    func testDifferentCertificatesProduceDifferentHashes() throws {
        let rsaCert = try certificate(fromDERBase64: Self.rsaCertificateDER)
        let ecCert = try certificate(fromDERBase64: Self.ecCertificateDER)
        XCTAssertNotEqual(
            CertificatePinning.spkiSHA256Hash(for: rsaCert),
            CertificatePinning.spkiSHA256Hash(for: ecCert)
        )
    }

    func testEvaluateReturnsNilForNonServerTrustChallenge() throws {
        let pinning = CertificatePinning(pinnedHashes: [Self.rsaExpectedSPKIHash])
        let protectionSpace = URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodHTTPBasic
        )
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: DummySender()
        )

        XCTAssertNil(pinning.evaluate(challenge))
    }

    private final class DummySender: NSObject, URLAuthenticationChallengeSender {
        func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
        func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
        func cancel(_ challenge: URLAuthenticationChallenge) {}
    }
}
