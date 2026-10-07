import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 휴대폰 잠금은 프로필과 무관하며 설치 표식이 일치할 때만 유효하다.
class GuardianLockStore {
  GuardianLockStore({
    required this.installationId,
    FlutterSecureStorage? secureStorage,
    DateTime Function()? now,
  }) : _secure = secureStorage ?? const FlutterSecureStorage(),
       _now = now ?? DateTime.now;

  static const storageKey = 'guardian.lock.v1';
  final String installationId;
  final FlutterSecureStorage _secure;
  final DateTime Function() _now;
  Future<void> _tail = Future.value();
  final _algorithm = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 600000, bits: 256);

  // 검증·오답 횟수 저장을 한 묶음으로 처리해 동시 입력으로 제한을 우회하지 못한다.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return result;
  }

  Future<Map<String, dynamic>?> _read() async {
    final raw = await _secure.read(key: storageKey);
    if (raw == null) return null;
    final record = jsonDecode(raw);
    if (record is! Map<String, dynamic> || record['installationId'] is! String ||
        record['salt'] is! String || record['verifier'] is! String ||
        record['attempts'] is! int || record['lockedUntil'] is! int) {
      throw StateError('E-PIN: invalid lock record');
    }
    if (record['installationId'] != installationId) return null;
    if (base64Decode(record['salt'] as String).length != 32 ||
        base64Decode(record['verifier'] as String).length != 32) {
      throw StateError('E-PIN: invalid verifier');
    }
    return record;
  }

  Future<bool> hasPin() => _serial(() async => await _read() != null);

  Future<void> setPin(String pin) => _serial(() async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) throw ArgumentError('E-PIN');
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final verifier = await _derive(pin, salt);
    await _secure.write(key: storageKey, value: jsonEncode({
      'installationId': installationId,
      'salt': base64Encode(salt),
      'verifier': base64Encode(verifier),
      'attempts': 0,
      'lockedUntil': 0,
    }));
  });

  Future<List<int>> _derive(String pin, List<int> salt) async =>
      (await _algorithm.deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt)).extractBytes();

  Future<bool> verifyPin(String pin) => _serial(() async {
    final record = await _read();
    if (record == null) return false;
    final now = _now().millisecondsSinceEpoch;
    if ((record['lockedUntil'] as int) > now) throw const GuardianPinLocked();
    if ((record['lockedUntil'] as int) != 0) record['attempts'] = 0;
    final actual = await _derive(pin, base64Decode(record['salt'] as String));
    final expected = base64Decode(record['verifier'] as String);
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    final valid = difference == 0;
    final attempts = valid ? 0 : (record['attempts'] as int) + 1;
    record['attempts'] = attempts;
    record['lockedUntil'] = attempts >= 5 ? now + const Duration(minutes: 5).inMilliseconds : 0;
    // 성공도 저장이 끝나기 전에는 통과시키지 않아 저장소 오류를 숨기지 않는다.
    await _secure.write(key: storageKey, value: jsonEncode(record));
    if (attempts >= 5) throw const GuardianPinLocked();
    return valid;
  });

  Future<void> clear() => _serial(() => _secure.delete(key: storageKey));
}

class GuardianPinLocked implements Exception {
  const GuardianPinLocked();
  @override
  String toString() => 'E-PIN-LOCKED';
}
