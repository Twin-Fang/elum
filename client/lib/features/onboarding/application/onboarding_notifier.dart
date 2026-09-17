import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../../guardian/data/member_repository.dart';
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
  /// 앱을 껐다 켜면 이 상태는 비어서 다시 만들어진다. 저장해 둔 값으로 되살리지
  /// 않으면 홈이 폴백(고양이·"우리 아이")을 그려, 온보딩에서 고른 캐릭터가
  /// 재시작마다 바뀌는 것처럼 보인다.
  ///
  /// PIN은 보안 저장소라 읽기가 비동기다. 여기서 기다리면 첫 프레임이 늦어지고
  /// 홈은 PIN을 쓰지도 않으므로 비워 둔다 — 필요한 화면이 직접 읽는다.
  @override
  OnboardingProfile build() {
    final storage = ref.read(localStorageProvider);
    return OnboardingProfile(
      childNickname: storage.nickname ?? '',
      supportGoals: storage.goals
          .map(SupportGoal.fromApiValue)
          .whereType<SupportGoal>()
          .toSet(),
      cardCharacter: CardCharacter.fromApiValue(storage.character),
    );
  }

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

  /// 기존 계정으로 복귀했을 때 온보딩을 건너뛴다.
  ///
  /// 이미 서버에 계정이 있는 이름이면 설정을 다시 받을 이유가 없다.
  /// 이름만 저장하고 완료 표시를 남겨 라우터 가드를 통과시킨다. (이슈 #19)
  Future<void> restoreCompleted(String childName) async {
    state = state.copyWith(childNickname: childName);

    final storage = ref.read(localStorageProvider);
    try {
      await storage.setNickname(childName);
      await storage.setOnboardingCompleted(true);
    } catch (e) {
      debugPrint('[onboarding] 복귀 저장 실패, 진행은 계속: $e');
    }
  }

  /// 온보딩 완료 — 수집한 값을 로컬과 서버에 저장한다.
  ///
  /// 로컬 저장은 즉시성(오프라인·화면 fallback)을, 서버 저장은 영속성(재설치·
  /// 기기 변경 시 복원)을 담당한다 (이슈 #89). 저장 실패가 데모를 막으면 안 되므로
  /// 예외를 삼키고 진행한다 — 서버 저장은 repository가, 로컬은 이 try가 흡수한다.
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
      debugPrint('[onboarding] 로컬 저장 실패, 진행은 계속: $e');
    }

    // 서버 연동 — nickname·goals·character를 계정에 남긴다. repository가 예외를
    // 삼키므로(throw하지 않음) 어느 하나가 실패해도 나머지와 온보딩 흐름은 이어진다.
    final member = ref.read(memberRepositoryProvider);
    await member.updateNickname(state.childNickname);
    await member.updateSupportGoals(
      state.supportGoals.map((g) => g.apiValue).toList(),
    );
    final character = state.cardCharacter;
    if (character != null) {
      await member.updateCharacter(character.apiValue);
    }
  }
}
