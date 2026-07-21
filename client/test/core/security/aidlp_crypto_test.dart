import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:elum/core/security/aidlp_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'test-master-secret-32bytes-minimum!!';

  test('seal한 봉투를 같은 규약으로 복호화하면 원문이 나온다', () async {
    const plain = '{"rawInputText":"홍길동 010-1234-5678"}';
    final sealed = await AidlpCrypto.seal(plain, secret: secret);

    // 같은 salt로 aesKey 재파생 → AES-GCM 복호화
    final salt = base64.decode(sealed.envelope.salt);
    final iv = base64.decode(sealed.envelope.iv);
    final ct = base64.decode(sealed.envelope.ciphertext); // cipherText+mac
    final aesKey = await AidlpCrypto.deriveKey(salt, 'elum-aes-gcm', secret);

    final algo = AesGcm.with256bits();
    final mac = ct.sublist(ct.length - 16);
    final cipherText = ct.sublist(0, ct.length - 16);
    final clear = await algo.decrypt(
      SecretBox(cipherText, nonce: iv, mac: Mac(mac)),
      secretKey: SecretKey(aesKey),
    );
    expect(utf8.decode(clear), plain);
  });

  test('HMAC 서명이 timestamp.nonce.ciphertext 규약을 따른다', () async {
    const plain = '{"text":"주민번호 900101-1234567"}';
    final sealed = await AidlpCrypto.seal(plain, secret: secret);

    final salt = base64.decode(sealed.envelope.salt);
    final hmacKey = await AidlpCrypto.deriveKey(salt, 'elum-hmac-sha256', secret);
    final signing = '${sealed.timestamp}.${sealed.nonce}.${sealed.envelope.ciphertext}';
    final hmac = Hmac.sha256();
    final expected = await hmac.calculateMac(
      utf8.encode(signing),
      secretKey: SecretKey(hmacKey),
    );
    expect(sealed.signature, base64.encode(expected.bytes));
  });

  test('같은 원문도 매번 다른 암호문을 만든다(salt/iv 랜덤)', () async {
    const plain = '{"text":"동일 입력"}';
    final a = await AidlpCrypto.seal(plain, secret: secret);
    final b = await AidlpCrypto.seal(plain, secret: secret);
    expect(a.envelope.ciphertext, isNot(b.envelope.ciphertext));
    expect(a.envelope.salt, isNot(b.envelope.salt));
  });
}
