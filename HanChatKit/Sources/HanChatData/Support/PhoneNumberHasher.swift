import Foundation
import CryptoKit

/// 전화번호 개인정보 보호: 원본 번호 대신 SHA-256 해시만 서버로 전송한다.
public enum PhoneNumberHasher {
    /// "010-1234-5678", "+82 10 1234 5678" → "821012345678" 형태로 정규화 후 해시.
    public static func hash(_ raw: String, defaultCountryCode: String = "82") -> String {
        let digits = raw.filter(\.isNumber)
        var normalized = digits
        if normalized.hasPrefix("0") {
            normalized = defaultCountryCode + normalized.dropFirst()
        }
        let data = Data(normalized.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
