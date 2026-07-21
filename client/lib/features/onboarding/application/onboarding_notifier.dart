import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../domain/character.dart';
import '../domain/onboarding_profile.dart';
import '../domain/support_goal.dart';

/// LocalStorage 주입 지점. main에서 초기화된 인스턴스로 override한다.
final localStorageProvider = Provider<LocalStorage>(
  (ref) => throw UnimplementedError('main에서 override해야 한다'),
);

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingProfile>(
  OnboardingNotifier.new,
);

/// 온보딩 입력 상태를 모은다.
///
/// 화면은 이 notifier만 보고, 저장소를 직접 건드리지 않는다.
class OnboardingNotifier extends Notifier<OnboardingProfile> {
  @override
  OnboardingProfile build() => const OnboardingProfile();

  void setNickname(String value) {
    state = state.copyWith(childNickname: value);
  }

  /// 목표는 다중 선택이다
  void toggleGoal(SupportGoal goal) {
    final next = Set<SupportGoal>.from(state.supportGoals);
    next.contains(goal) ? next.remove(goal) : next.add(goal);
    state = state.copyWith(supportGoals: next);
  }

  void setGoals(Set<SupportGoal> goals) {
    state = state.copyWith(supportGoals: goals);
  }

  /// 캐릭터는 단일 선택이다
  void setCharacter(CardCharacter character) {
    state = state.copyWith(cardCharacter: character);
  }

  void setPin(String pin) {
    state = state.copyWith(guardianPin: pin);
  }

  /// 온보딩 완료 — 수집한 4개 값을 로컬에 저장한다.
  /// 저장 실패가 데모를 막으면 안 되므로 예외를 삼키고 진행한다.
  Future<void> complete() async {
    final storage = ref.read(localStorageProvider);
    try {
      await storage.setNickname(state.childNickname);
      await storage.setGoals(
        state.supportGoals.map((g) => g.apiValue).toList(),
      );
      final character = state.cardCharacter;
      if (character != null) {
        await storage.setCharacter(character.apiValue);
      }
      await storage.setPin(state.guardianPin);
      await storage.setOnboardingCompleted(true);
    } catch (e) {
      debugPrint('[onboarding] 저장 실패, 진행은 계속: $e');
    }
  }
}
