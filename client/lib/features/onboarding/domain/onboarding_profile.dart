import 'package:freezed_annotation/freezed_annotation.dart';

import 'character.dart';
import 'support_goal.dart';

part 'onboarding_profile.freezed.dart';

/// 온보딩이 수집하는 정보의 전부.
///
/// 호칭 / 도움 목표 / 카드 캐릭터 / PIN — 이 4개뿐이다.
/// 필드를 추가할 땐 "진단명 없는 개인화" 원칙을 깨는지 먼저 검토한다.
@freezed
abstract class OnboardingProfile with _$OnboardingProfile {
  const factory OnboardingProfile({
    /// 아이 호칭. 실명이 아니어도 된다고 온보딩에서 안내한다.
    @Default('') String childNickname,
    @Default(<SupportGoal>{}) Set<SupportGoal> supportGoals,
    CardCharacter? cardCharacter,

    /// 보호자 모드 전환용 4자리 PIN
    @Default('') String guardianPin,
  }) = _OnboardingProfile;

  const OnboardingProfile._();

  /// PIN 자릿수 — 화면과 검증이 같은 값을 보게 한다
  static const pinLength = 4;

  /// 호칭이 없을 때 제목에 쓸 대체어.
  /// 딥링크로 중간 진입하면 호칭이 비어 "의 어떤 순간을..."처럼 조사만 남는다.
  static const _nicknameFallback = '우리 아이';

  /// 화면 제목에 넣을 호칭. 비어있으면 자연스러운 대체어를 준다.
  String get displayName =>
      childNickname.trim().isEmpty ? _nicknameFallback : childNickname.trim();

  // 각 단계의 진행 조건을 모델이 스스로 안다.
  // 화면마다 조건을 재구현하면 하나만 틀려도 CTA가 잘못 열린다.
  bool get canProceedFromName => childNickname.trim().isNotEmpty;
  bool get canProceedFromGoals => supportGoals.isNotEmpty;
  bool get canProceedFromCharacter => cardCharacter != null;
  bool get isPinComplete => guardianPin.length == pinLength;

  /// 온보딩 전체 완료 여부 — 라우터 redirect 판단에 쓴다
  bool get isComplete =>
      canProceedFromName &&
      canProceedFromGoals &&
      canProceedFromCharacter &&
      isPinComplete;
}
