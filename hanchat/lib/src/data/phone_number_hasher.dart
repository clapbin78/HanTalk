import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 전화번호 개인정보 보호: 원본 대신 SHA-256 해시만 서버로 전송.
/// Swift 버전과 동일 알고리즘 — 플랫폼 간 해시 호환.
class PhoneNumberHasher {
  const PhoneNumberHasher._();

  /// "010-1234-5678", "+82 10 1234 5678" → "821012345678" 정규화 후 해시.
  static String hash(String raw, {String defaultCountryCode = '82'}) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = defaultCountryCode + digits.substring(1);
    }
    return sha256.convert(utf8.encode(digits)).toString();
  }
}
