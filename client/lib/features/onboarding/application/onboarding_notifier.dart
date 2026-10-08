import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/storage/local_storage.dart';
import '../../member/data/member_repository.dart';
import '../../profile/domain/profile_summary.dart';
import '../../../shared/models/character.dart';
import '../domain/image_style.dart';
import '../domain/onboarding_profile.dart';
import '../../../shared/models/support_goal.dart';

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
      // 로컬 값이 없을 때 — 온보딩 중이면 새 이룸이라 기본 그림, 온보딩을 마친
      // 기존 설치 앱이면 서버 기본값과 같은 만화다.
      imageStyle: storage.imageStyle == null && !storage.isOnboardingCompleted
          ? ImageStyle.onboardingDefault
          : ImageStyle.fromApiValue(storage.imageStyle),
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

  /// 그림 방식은 단일 선택이다. 온보딩에서는 상태에만 담고 [complete]가 한꺼번에 저장한다.
  void setImageStyle(ImageStyle style) {
    state = state.copyWith(imageStyle: style);
  }

  /// 설정에서 그림 방식을 바꾼다 — 화면·로컬·서버에 바로 남긴다 (#458).
  ///
  /// 로컬 저장이 먼저고 서버 저장은 그 뒤다. **서버가 실패하면 이전 값으로 되돌린다.**
  /// 서버 값이 곧 AI 그림 생성 여부(크레딧)를 정하므로, 실패했는데 화면만 "직접 사진"으로
  /// 남으면 AI를 껐다고 믿는 사이 서버는 계속 그림을 만든다. 되돌린 뒤 부르는 쪽이
  /// 돌려받은 실패로 에러 코드를 띄운다. null 이면 서버까지 저장됐다.
  Future<AppFailure?> changeImageStyle(ImageStyle style) async {
    final previous = state.imageStyle;
    state = state.copyWith(imageStyle: style);
    try {
      await ref.read(localStorageProvider).setImageStyle(style.apiValue);
    } catch (e) {
      debugPrint('[onboarding] 그림 방식 로컬 저장 실패, 서버 저장은 시도: $e');
    }
    final failure = await ref
        .read(memberRepositoryProvider)
        .updateImageStyle(style.apiValue);
    if (failure == null) return null;

    // 서버와 어긋난 채 남지 않게 화면·로컬을 이전 값으로 복원한다
    state = state.copyWith(imageStyle: previous);
    try {
      await ref.read(localStorageProvider).setImageStyle(previous.apiValue);
    } catch (e) {
      debugPrint('[onboarding] 그림 방식 로컬 복원 실패: $e');
    }
    return failure;
  }

  void setPin(String pin) {
    state = state.copyWith(guardianPin: pin);
  }

  /// 서버가 알려 준 이룸이 값으로 화면·로컬을 맞춘다 (다중 보호자 #362 · E44).
  ///
  /// 로컬에는 이룸이 값(이름·캐릭터·도움 목표·그림 방식)이 **한 벌뿐**이다. 이룸이를 바꾸거나
  /// 초대로 합류하면 서버 값을 우선해 덮는다 — 안 덮으면 다른 이룸이의 이름이 남아 홈 인사말에
  /// 뜨고, 일과를 만들 때 그 이룸이의 도움 목표가 AI 로 간다.
  ///
  /// [goals] 는 서버 enum 값이다. null 이면 건드리지 않는다 (목록 항목에는 도움 목표가 없다).
  /// 저장 실패는 화면 상태를 막지 않는다 — 서버 값이 곧 진실이고 다음 조회에 다시 맞춘다.
  Future<void> applyServerProfile(
    ProfileSummary profile, {
    List<String>? goals,
  }) async {
    final character =
        CardCharacter.fromApiValue(profile.character) ?? state.cardCharacter;
    final parsedGoals = goals
        ?.map(SupportGoal.fromApiValue)
        .whereType<SupportGoal>()
        .toSet();
    state = state.copyWith(
      childNickname: profile.nickname ?? '',
      cardCharacter: character,
      imageStyle: profile.imageStyle,
      supportGoals: parsedGoals ?? state.supportGoals,
    );

    final storage = ref.read(localStorageProvider);
    try {
      await storage.setNickname(profile.nickname ?? '');
      if (character != null) await storage.setCharacter(character.apiValue);
      await storage.setImageStyle(profile.imageStyle.apiValue);
      if (parsedGoals != null) {
        await storage.setGoals(parsedGoals.map((g) => g.apiValue).toList());
      }
    } catch (e) {
      debugPrint('[onboarding] 이룸이 값 로컬 저장 실패, 화면은 서버 값으로 간다: $e');
    }
  }

  /// 이룸이 값을 전부 비운다 — 연결된 이룸이가 하나도 없을 때 (E29).
  ///
  /// 비밀암호는 **이룸이가 아니라 이 휴대폰의 것**이라 저장소에서 지킨다 (E45). 여기서는
  /// 화면 상태만 비운다.
  void resetProfile() {
    state = const OnboardingProfile();
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
  /// 기기 변경 시 복원)을 담당한다 (이슈 #89).
  ///
  /// **온보딩 흐름은 막지 않는다.** 로컬에 저장돼 있으면 앱은 그대로 쓸 수 있고,
  /// 여기서 앞을 막으면 서버가 잠깐 흔들릴 때 시작조차 못 한다.
  /// 대신 **서버 저장이 온전했는지를 돌려준다** — 부르는 쪽이 알려야
  /// 보호자가 "설정이 저장된 줄 알았는데 재설치하니 사라졌다"를 겪지 않는다.
  ///
  /// null 이면 셋 다 저장됐다. 하나라도 실패하면 **처음 실패한 이유**를 돌려준다 —
  /// 서버가 왜 거절했는지(잘못된 값·정지된 계정 등)를 화면이 그대로 띄운다 (#352).
  Future<AppFailure?> complete() async {
    // 저장하는 사이 서버 응답이 상태를 덮어도 사용자가 입력한 값이 나가도록 시작 시점 값을 고정한다.
    // 아니면 그림 방식이 기본값(만화)으로 저장돼 AI 그림 비용이 나간다.
    final input = state;
    final storage = ref.read(localStorageProvider);
    try {
      await storage.setNickname(input.childNickname);
      await storage.setGoals(
        input.supportGoals.map((g) => g.apiValue).toList(),
      );
      final character = input.cardCharacter;
      if (character != null) {
        await storage.setCharacter(character.apiValue);
      }
      // 건너뛴 경우에도 기본값(만화)이 명시로 남는다
      await storage.setImageStyle(input.imageStyle.apiValue);
      await storage.setPin(input.guardianPin);
      await storage.setOnboardingCompleted(true);
    } catch (e) {
      debugPrint('[onboarding] 로컬 저장 실패: $e');
      // 잠금 저장이 실패했는데 홈으로 가면 보호자 화면의 경계가 사라진다.
      return AppFailure.of(e);
    }

    // 서버 연동 — nickname·goals·character·imageStyle을 계정에 남긴다. 하나가
    // 실패해도 나머지는 시도한다 — 일부라도 남는 편이 낫다. (`??=` 로 이으면 앞이 실패할 때
    // 뒤 호출이 통째로 건너뛰어진다.)
    final member = ref.read(memberRepositoryProvider);
    final character = input.cardCharacter;
    final failures = <AppFailure?>[
      await member.updateNickname(input.childNickname),
      await member.updateSupportGoals(
        input.supportGoals.map((g) => g.apiValue).toList(),
      ),
      if (character != null) await member.updateCharacter(character.apiValue),
      await member.updateImageStyle(input.imageStyle.apiValue),
    ];
    // 저장하는 사이 서버 응답이 상태를 비웠다면 저장한 값으로 되돌린다 — 설정 화면이 기본값을 보이지 않게.
    if (ref.mounted && state != input) state = input;
    // 처음 실패한 이유를 돌려준다
    return failures.whereType<AppFailure>().firstOrNull;
  }
}
