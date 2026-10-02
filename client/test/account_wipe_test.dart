import 'dart:async';
import 'dart:io';

import 'package:elum/core/storage/account_wipe.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/guardian/data/card_image_disk_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// 계정 로컬 정리 — 보호자·이룸이의 로그아웃·탈퇴가 같은 함수로 비운다.
void main() {
  test('토큰·이룸이 표식·역할·이룸이 정보를 지우고 카드 그림 캐시 삭제를 부른다', () async {
    final storage = InMemoryStorage(elumiDevice: true, onboardingCompleted: true);
    await storage.setSelectedRole(AppRole.elumi.storageValue);
    await storage.setNickname('하늘이');
    final tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
    final cache = _SlowCache()..release.complete();

    await wipeLocalAccount(tokens: tokens, storage: storage, imageCache: cache);

    expect(tokens.hasSession, isFalse);
    expect(storage.isElumiDevice, isFalse);
    expect(storage.selectedRole, isNull);
    expect(storage.nickname, isNull);
    expect(cache.clearCalls, 1);
  });

  test('캐시 삭제가 끝난 뒤에 돌아온다 — 끝났다고 알린 뒤에 사진이 남으면 안 된다', () async {
    final cache = _SlowCache();
    var done = false;

    final wipe = wipeLocalAccount(
      tokens: InMemoryTokenStore(accessToken: 'a', refreshToken: 'r'),
      storage: InMemoryStorage(),
      imageCache: cache,
    ).then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse, reason: '삭제가 아직 진행 중이다');

    cache.release.complete();
    await wipe;
    expect(cache.finished, isTrue);
  });
}

/// 삭제가 [release] 될 때까지 끝나지 않는 캐시.
class _SlowCache extends CardImageDiskCache {
  _SlowCache() : super(rootProvider: () async => Directory.systemTemp);

  final release = Completer<void>();
  int clearCalls = 0;
  bool finished = false;

  @override
  Future<void> clear() async {
    clearCalls++;
    await release.future;
    finished = true;
  }
}
