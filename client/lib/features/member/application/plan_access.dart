import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_plan_override.dart';
import 'member_providers.dart';

/// 화면이 묻는 Free·Pro 판정 한 벌. 새 Pro 기능은 여기에 값을 더하고 화면은 이것만 본다
///
/// 원본은 서버 권한(`entitlements`). 개발자 도구 요금제 흉내가 켜져 있으면 그 값으로 덮는다.
@immutable
class PlanAccess {
  const PlanAccess({
    required this.isPro,
    required this.canExportCardsWithoutWatermark,
    required this.canUseAllCardDesignThemes,
    required this.canUseGuardianVoice,
  });

  /// 모르거나 Free 일 때 (워터마크 넣음 · 기본 테마만)
  static const free = PlanAccess(
    isPro: false,
    canExportCardsWithoutWatermark: false,
    canUseAllCardDesignThemes: false,
    canUseGuardianVoice: false,
  );

  /// 개발자 도구 `Pro 처럼`
  static const pro = PlanAccess(
    isPro: true,
    canExportCardsWithoutWatermark: true,
    canUseAllCardDesignThemes: true,
    canUseGuardianVoice: true,
  );

  final bool isPro;

  /// 앱에서 Pro 를 살 수 있는가. 인앱 결제(#1072)가 붙기 전에는 false —
  /// 살 방법이 없는데 Pro 잠금만 보이면 막힌 기능처럼 느껴져, 그동안은 Pro 전용 선택지를 숨긴다
  static const canPurchasePro = false;

  /// 카드 내보내기에서 로고·워터마크를 뺄 수 있는가
  final bool canExportCardsWithoutWatermark;

  /// 카드 내보내기에서 기본 말고 다른 디자인 테마를 고를 수 있는가
  final bool canUseAllCardDesignThemes;

  /// 카드마다 보호자 목소리를 녹음할 수 있는가. 꺼져도 이미 한 녹음은 남고(듣기·지우기 가능) 이룸이는 기본 음성으로 듣는다
  final bool canUseGuardianVoice;
}

/// 지금 계정의 Free·Pro 판정 (회원 조회 중·실패면 Free 로 본다)
final planAccessProvider = Provider<PlanAccess>((ref) {
  switch (ref.watch(devPlanOverrideProvider)) {
    case DevPlanOverride.free:
      return PlanAccess.free;
    case DevPlanOverride.pro:
      return PlanAccess.pro;
    case DevPlanOverride.server:
      break;
  }
  final member = ref.watch(memberProvider).value;
  if (member == null) return PlanAccess.free;
  return PlanAccess(
    isPro: member.isPro,
    canExportCardsWithoutWatermark: member.canExportCardsWithoutWatermark,
    canUseAllCardDesignThemes: member.canUseAllCardDesignThemes,
    canUseGuardianVoice: member.canUseGuardianVoice,
  );
});
