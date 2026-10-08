import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/l10n/current_l10n.dart';
import '../../../shared/models/character.dart';
import 'image_style.dart';
import '../../../shared/models/support_goal.dart';

part 'onboarding_profile.freezed.dart';

/// 온보딩이 수집하는 정보의 전부.
///
/// 호칭 / 도움 목표 / 카드 캐릭터 / 그림 방식 / PIN — 이 5개뿐이다.
/// 필드를 추가할 땐 "진단명 없는 개인화" 원칙을 깨는지 먼저 검토한다.
///
/// 그림 방식(#458)은 **서비스 원칙 1(진단명·장애 유형 수집 금지)을 어기지 않는다.**
/// 이룸이가 어떤 사람인지가 아니라 "카드 그림을 어떤 방식으로 만들지"라는 화면
/// 취향이고, 만화·실사·직접 사진은 캐릭터 고르기와 같은 성격의 선택이다.
/// 원칙 2·5도 해당 없다 — 보호자 입력 원문이 아니라 세 값 중 하나만 저장한다.
@freezed
abstract class OnboardingProfile with _$OnboardingProfile {
  const factory OnboardingProfile({
    /// 아이 호칭. 실명이 아니어도 된다고 온보딩에서 안내한다.
    @Default('') String childNickname,
    @Default(<SupportGoal>{}) Set<SupportGoal> supportGoals,
    CardCharacter? cardCharacter,

    /// 카드 그림 방식. 새 이룸이는 기본 그림으로 시작한다.
    @Default(ImageStyle.onboardingDefault) ImageStyle imageStyle,

    /// 보호자 모드 전환용 4자리 PIN
    @Default('') String guardianPin,
  }) = _OnboardingProfile;

  const OnboardingProfile._();

  /// PIN 자릿수 — 화면과 검증이 같은 값을 보게 한다
  static const pinLength = 4;

  /// 화면 제목에 넣을 호칭. 비어있으면 자연스러운 대체어(이룸이)를 준다.
  /// 딥링크로 중간 진입하면 호칭이 비어 "의 어떤 순간을..."처럼 조사만 남는다.
  String get displayName => childNickname.trim().isEmpty
      ? appL10n.commonElumiName
      : childNickname.trim();

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
