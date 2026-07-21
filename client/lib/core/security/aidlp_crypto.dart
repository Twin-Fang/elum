import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 서버로 보낼 암호문 봉투. 요청 본문의 `encrypted` 필드가 된다.
class AidlpEnvelope {
  const AidlpEnvelope({required this.ciphertext, required this.iv, required this.salt});
  final String ciphertext; // base64(cipherText+mac) — 서버 Java Cipher 출력과 동일 순서
  final String iv; // base64(12바이트 GCM nonce)
  final String salt; // base64(16바이트 HKDF salt)

  Map<String, dynamic> toJson() => {'ciphertext': ciphertext, 'iv': iv, 'salt': salt};
}

/// 봉투 + 재전송 방지 헤더 값 묶음.
class AidlpSealed {
  const AidlpSealed({
    required this.envelope,
    required this.timestamp,
    required this.nonce,
    required this.signature,
  });
  final AidlpEnvelope envelope;
  final String timestamp; // epoch millis
  final String nonce; // base64(16바이트)
  final String signature; // base64(HMAC-SHA256)
}

/// AI DLP 요청 암호화. 서버 AidlpCryptoService와 규약(HKDF info 라벨·바이트 순서·서명 문자열)을 맞춘다.
abstract final class AidlpCrypto {
  static final Random _random = Random.secure();

  /// 평문 JSON을 AES-256-GCM으로 봉인하고 HMAC 서명까지 만든다.
  static Future<AidlpSealed> seal(String plaintextJson, {required String secret}) async {
    final salt = _randomBytes(16);
    final iv = _randomBytes(12);
    final nonce = _randomBytes(16);

    final aesKey = await deriveKey(salt, 'elum-aes-gcm', secret);
    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(
      utf8.encode(plaintextJson),
      secretKey: SecretKey(aesKey),
      nonce: iv,
    );
    // 서버는 cipherText+tag를 하나로 받는다 → concatenation 순서(cipherText + mac).
    final ct = <int>[...box.cipherText, ...box.mac.bytes];

    final ctB64 = base64.encode(ct);
    final ivB64 = base64.encode(iv);
    final saltB64 = base64.encode(salt);
    final nonceB64 = base64.encode(nonce);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    final hmacKey = await deriveKey(salt, 'elum-hmac-sha256', secret);
    final signing = '$timestamp.$nonceB64.$ctB64';
    final sigMac = await Hmac.sha256().calculateMac(
      utf8.encode(signing),
      secretKey: SecretKey(hmacKey),
    );

    return AidlpSealed(
      envelope: AidlpEnvelope(ciphertext: ctB64, iv: ivB64, salt: saltB64),
      timestamp: timestamp,
      nonce: nonceB64,
      signature: base64.encode(sigMac.bytes),
    );
  }

  /// HKDF-SHA256(RFC 5869) 단일 블록. Extract(salt, secret) → Expand(prk, info, 32B).
  static Future<List<int>> deriveKey(List<int> salt, String info, String secret) async {
    final hmac = Hmac.sha256();
    // Extract
    final prk = await hmac.calculateMac(utf8.encode(secret), secretKey: SecretKey(salt));
    // Expand: T(1) = HMAC(prk, info || 0x01)
    final input = <int>[...utf8.encode(info), 0x01];
    final t1 = await hmac.calculateMac(input, secretKey: SecretKey(prk.bytes));
    return t1.bytes.sublist(0, 32);
  }

  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }
}
