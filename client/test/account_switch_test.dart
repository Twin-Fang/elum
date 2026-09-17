import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';

/// 다른 계정으로 로그인했을 때 이전 아이 정보가 남으면, 이름 입력칸에 남의 이름이
/// 미리 채워지고 거기에 입력하면 이어붙는다 (이슈 #177).
///
/// 토큰은 방금 받은 것이므로 함께 지우면 안 된다 — 그러면 로그인이 풀린다.
void main() {
  Future<InMemoryStorage> filled() async {
    final s = InMemoryStorage(onboardingCompleted: true, pin: '1234');
    await s.setNickname('민수');
    await s.setGoals(['STEP_BY_STEP']);
    await s.setCharacter('POPO');
    await s.setAccessToken('token-abc');
    await s.setRoutineProgressJson('r1', '{"done":true}');
    await s.setCachedTodayRoutinesJson('[{"id":"r1"}]');
    return s;
  }

  test('아이 정보만 지우고 토큰은 남긴다', () async {
    final s = await filled();

    await s.clearChildProfile();

    expect(s.nickname, isNull, reason: '이전 아이 이름이 남으면 새 이름과 이어붙는다');
    expect(s.goals, isEmpty);
    expect(s.character, isNull);
    expect(s.isOnboardingCompleted, isFalse);
    expect(await s.getPin(), isNull);
    expect(s.getRoutineProgressJson('r1'), isNull, reason: '이전 아이의 체크 기록');
    expect(s.cachedTodayRoutinesJson, isNull);

    expect(s.accessToken, 'token-abc', reason: '방금 로그인했으므로 토큰은 살아야 한다');
  });

  test('clearAll은 토큰까지 지운다 — 이것이 로그아웃이다', () async {
    final s = await filled();

    await s.clearAll();

    expect(s.nickname, isNull);
    expect(s.accessToken, isNull);
  });

  test('비어 있는 저장소에 호출해도 터지지 않는다', () async {
    final s = InMemoryStorage();
    await s.clearChildProfile();
    expect(s.nickname, isNull);
  });

  test('저장소를 비워도 provider를 다시 읽지 않으면 화면에 남는다', () async {
    // 앱이 켜질 때 provider가 값을 메모리에 올린다. 저장소만 비우면 화면은 그대로다 —
    // 실기기에서 이 상태로 이름 입력칸에 이전 이름이 남아 있었다 (이슈 #177).
    final storage = await filled();
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    expect(container.read(onboardingProvider).childNickname, '민수');

    await storage.clearChildProfile();
    expect(container.read(onboardingProvider).childNickname, '민수',
        reason: '저장소만 비우면 메모리에는 남는다 — 이것이 버그였다');

    container.invalidate(onboardingProvider);
    expect(container.read(onboardingProvider).childNickname, isEmpty,
        reason: '다시 읽어야 비워진다');
  });
}
