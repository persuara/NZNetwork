import Foundation
import Security
import CryptoKit

/// A ready-made SSL/TLS certificate-pinning helper for `InterceptorProtocol.handle(challenge:)`
/// (or the equivalent hooks on `NZDownloaderDelegate`/`NZSocketDelegate`).
///
/// Pins against the Subject Public Key Info (SPKI) of the server's certificate chain — the
/// approach recommended by OWASP's certificate/public-key pinning guidance, since it survives
/// certificate renewal as long as the key itself doesn't change, unlike pinning the whole
/// certificate.
///
/// ```swift
/// let pinning = CertificatePinning(pinnedHashes: ["k3XT+2e2Nq3s+E2/w7wKKVArgOJ/HydIQNfEmoWDA/o="])
///
/// func handle(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
///     pinning.evaluate(challenge) ?? (.performDefaultHandling, nil)
/// }
/// ```
public struct CertificatePinning {

    /// Base64-encoded SHA-256 hashes of the pinned public keys' SPKI representation. Generate one with:
    /// `openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64`
    public let pinnedHashes: Set<String>

    public init(pinnedHashes: Set<String>) {
        self.pinnedHashes = pinnedHashes
    }

    /// Evaluates a server-trust authentication challenge against `pinnedHashes`.
    ///
    /// - Parameter challenge: The challenge presented by the server.
    /// - Returns: `nil` if `challenge` isn't a server-trust challenge — so the caller can fall
    ///   back to its own handling for other authentication methods (client certificates,
    ///   Basic/NTLM, ...) — otherwise `.useCredential` if the chain is both trusted by the system
    ///   and contains a pinned public key, or `.cancelAuthenticationChallenge` otherwise.
    public func evaluate(_ challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?)? {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return nil
        }

        guard isTrustedAndPinned(serverTrust) else {
            return (.cancelAuthenticationChallenge, nil)
        }

        return (.useCredential, URLCredential(trust: serverTrust))
    }

    private func isTrustedAndPinned(_ trust: SecTrust) -> Bool {
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else { return false }

        // SecTrustGetCertificateAtIndex is deprecated in favor of SecTrustCopyCertificateChain,
        // but that replacement requires iOS 15+; this package's minimum deployment target is iOS 13.
        let certificateCount = SecTrustGetCertificateCount(trust)
        for index in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(trust, index) else { continue }
            if let hash = Self.spkiSHA256Hash(for: certificate), pinnedHashes.contains(hash) {
                return true
            }
        }
        return false
    }

    /// Computes the base64-encoded SHA-256 hash of a certificate's Subject Public Key Info
    /// (SPKI). Supports RSA 2048/4096 and EC P-256/P-384 keys — the algorithms in common use for
    /// publicly-trusted TLS certificates. Returns `nil` for other key types.
    public static func spkiSHA256Hash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let attributes = SecKeyCopyAttributes(publicKey) as? [CFString: Any],
              let keyType = attributes[kSecAttrKeyType] as? String,
              let keySizeInBits = attributes[kSecAttrKeySizeInBits] as? Int,
              let header = asn1Header(keyType: keyType, keySizeInBits: keySizeInBits)
        else {
            return nil
        }

        var spkiData = Data(header)
        spkiData.append(keyData)

        let digest = SHA256.hash(data: spkiData)
        return Data(digest).base64EncodedString()
    }

    // Standard DER-encoded SPKI algorithm headers, prepended to the raw public key bytes
    // `SecKeyCopyExternalRepresentation` returns, to reconstruct the full SPKI structure that
    // gets hashed for pinning (the same well-known constants used across the industry, e.g. by
    // OWASP's and TrustKit's pinning guides).
    private static let rsa2048Asn1Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48,
        0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]
    private static let rsa4096Asn1Header: [UInt8] = [
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48,
        0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0f, 0x00
    ]
    private static let ecdsaSecp256r1Asn1Header: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d,
        0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00
    ]
    private static let ecdsaSecp384r1Asn1Header: [UInt8] = [
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d,
        0x02, 0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
    ]

    private static func asn1Header(keyType: String, keySizeInBits: Int) -> [UInt8]? {
        if keyType == (kSecAttrKeyTypeRSA as String) {
            switch keySizeInBits {
            case 2048: return rsa2048Asn1Header
            case 4096: return rsa4096Asn1Header
            default: return nil
            }
        }
        if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) {
            switch keySizeInBits {
            case 256: return ecdsaSecp256r1Asn1Header
            case 384: return ecdsaSecp384r1Asn1Header
            default: return nil
            }
        }
        return nil
    }
}
