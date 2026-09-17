import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';

/// 앱을 껐다 켜면 온보딩 상태는 메모리에서 사라진다.
/// 저장해 둔 값으로 되살리지 않으면 홈이 폴백을 그려, 고른 캐릭터가
/// 재시작마다 고양이로 돌아가는 것처럼 보인다 (실기기 E2E에서 발견).
void main() {
  ProviderContainer containerWith(LocalStorage storage) {
    final container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('저장된 값이 있으면 그대로 되살린다', () async {
    final storage = InMemoryStorage(onboardingCompleted: true);
    await storage.setNickname('보름이');
    await storage.setGoals([SupportGoal.values.first.apiValue]);
    await storage.setCharacter(CardCharacter.fox.apiValue);

    final profile = containerWith(storage).read(onboardingProvider);

    expect(profile.childNickname, '보름이');
    expect(profile.cardCharacter, CardCharacter.fox);
    expect(profile.supportGoals, {SupportGoal.values.first});
  });

  test('저장된 값이 없으면 빈 상태로 시작한다', () {
    final profile = containerWith(InMemoryStorage()).read(onboardingProvider);

    expect(profile.childNickname, isEmpty);
    expect(profile.cardCharacter, isNull);
    expect(profile.supportGoals, isEmpty);
  });

  test('모르는 캐릭터 값이면 임의로 고르지 않고 비워 둔다', () async {
    // 구버전 데이터나 서버 enum 추가로 들어올 수 있다.
    final storage = InMemoryStorage();
    await storage.setCharacter('UNKNOWN_CHARACTER');

    expect(containerWith(storage).read(onboardingProvider).cardCharacter, isNull);
  });

  test('저장된 목표 중 모르는 값은 버리고 나머지를 살린다', () async {
    final storage = InMemoryStorage();
    await storage.setGoals(['NOT_A_GOAL', SupportGoal.values.last.apiValue]);

    final goals = containerWith(storage).read(onboardingProvider).supportGoals;

    expect(goals, {SupportGoal.values.last});
  });
}
