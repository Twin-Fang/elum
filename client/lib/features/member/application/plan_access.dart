import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_plan_override.dart';
import '../../subscription/application/plan_store_catalog.dart';
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
    required this.canViewWeeklyReport,
    required this.canTranslateRoutines,
    required this.canScheduleRoutines,
    this.canPurchasePro = false,
  });

  /// 모르거나 Free 일 때 (워터마크 넣음 · 기본 테마만 · 주간 리포트 없음)
  static const free = PlanAccess(
    isPro: false,
    canExportCardsWithoutWatermark: false,
    canUseAllCardDesignThemes: false,
    canViewWeeklyReport: false,
    canTranslateRoutines: false,
    canScheduleRoutines: false,
  );

  /// 개발자 도구 `Pro 처럼`
  static const pro = PlanAccess(
    isPro: true,
    canExportCardsWithoutWatermark: true,
    canUseAllCardDesignThemes: true,
    canViewWeeklyReport: true,
    canTranslateRoutines: true,
    canScheduleRoutines: true,
  );

  final bool isPro;

  /// 앱에서 Pro 를 살 수 있는가 (판매 스위치 + 스토어 연결 + 상품 불러옴, [canPurchaseProProvider]).
  /// false 면 Pro 전용 선택지·`Pro 알아보기` 를 숨긴다 — 살 방법이 없는데 잠금만 보이면 막힌 기능처럼 느껴짐
  final bool canPurchasePro;

  /// 카드 내보내기에서 로고·워터마크를 뺄 수 있는가
  final bool canExportCardsWithoutWatermark;

  /// 카드 내보내기에서 기본 말고 다른 디자인 테마를 고를 수 있는가
  final bool canUseAllCardDesignThemes;

  /// 주간 리포트를 볼 수 있는가
  final bool canViewWeeklyReport;

  /// 만든 일과를 다른 언어 사본으로 만들 수 있는가 (일과관리 메뉴 `다른 언어로 만들기`)
  final bool canTranslateRoutines;

  /// 일과에 요일·시각을 정할 수 있는가 (반복 일과 · 주간 계획 · 이룸이 기기 알림). 보호자 화면에서만 본다
  final bool canScheduleRoutines;
}

/// 지금 계정의 Free·Pro 판정 (회원 조회 중·실패면 Free 로 본다)
final planAccessProvider = Provider<PlanAccess>((ref) {
  final access = _readPlanAccess(ref);
  return PlanAccess(
    isPro: access.isPro,
    canExportCardsWithoutWatermark: access.canExportCardsWithoutWatermark,
    canUseAllCardDesignThemes: access.canUseAllCardDesignThemes,
    canViewWeeklyReport: access.canViewWeeklyReport,
    canTranslateRoutines: access.canTranslateRoutines,
    canScheduleRoutines: access.canScheduleRoutines,
    canPurchasePro: ref.watch(canPurchaseProProvider),
  );
});

/// 권한 원본: 개발자 도구 흉내 > 서버 권한 > (모르면) Free
PlanAccess _readPlanAccess(Ref ref) {
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
    canViewWeeklyReport: member.canViewWeeklyReport,
    canTranslateRoutines: member.canTranslateRoutines,
    canScheduleRoutines: member.canScheduleRoutines,
  );
}
