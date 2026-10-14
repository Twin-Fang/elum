import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:elum/core/storage/guardian_lock_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('반복 횟수를 줄여도 옛 기록의 비밀암호로 열리고, 새 횟수로 바뀐다', () async {
    // 깨지면: 업데이트한 보호자가 원래 비밀암호로 보호자 화면에 못 들어간다.
    final salt = List<int>.filled(32, 7);
    final legacy = await (await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: GuardianLockStore.legacyIterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode('1234')), nonce: salt))
        .extractBytes();
    FlutterSecureStorage.setMockInitialValues({
      GuardianLockStore.storageKey: jsonEncode({
        'installationId': 'i',
        'salt': base64Encode(salt),
        'verifier': base64Encode(legacy),
        'attempts': 0,
        'lockedUntil': 0,
      }),
    });
    final store = GuardianLockStore(installationId: 'i');

    expect(await store.verifyPin('1234'), isTrue);
    final saved = jsonDecode(
      (await const FlutterSecureStorage().read(key: GuardianLockStore.storageKey))!,
    );
    expect(saved['iterations'], GuardianLockStore.iterations);
    expect(await store.verifyPin('1234'), isTrue);
    expect(await store.verifyPin('0000'), isFalse);
  });
}
