import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_plan_override.dart';
import '../../subscription/application/plan_store_catalog.dart';
import '../domain/plan_entitlements.dart';
import 'member_providers.dart';

/// 화면이 묻는 Free·Pro 판정 한 벌: 서버 권한 묶음([PlanEntitlements]) + 앱에서 살 수 있는가
///
/// 원본은 서버 권한(`entitlements`). 개발자 도구 요금제 흉내가 켜져 있으면 그 값으로 덮는다.
/// 새 Pro 기능은 [PlanEntitlements] 에 값을 더하고 여기에 전달 getter 한 줄. 화면은 이것만 본다
@immutable
class PlanAccess {
  const PlanAccess({required this.entitlements, this.canPurchasePro = false});

  /// 모르거나 Free 일 때 (워터마크 넣음 · 기본 테마만 · Pro 기능 전부 꺼짐)
  static const free = PlanAccess(entitlements: PlanEntitlements.free);

  /// 개발자 도구 `Pro 처럼`
  static const pro = PlanAccess(entitlements: PlanEntitlements.pro);

  /// 서버 권한 묶음 (개발자 도구 흉내면 그 묶음)
  final PlanEntitlements entitlements;

  /// 앱에서 Pro 를 살 수 있는가 (판매 스위치 + 스토어 연결 + 상품 불러옴, [canPurchaseProProvider]).
  /// false 면 Pro 전용 선택지·`Pro 알아보기` 를 숨긴다 — 살 방법이 없는데 잠금만 보이면 막힌 기능처럼 느껴짐
  final bool canPurchasePro;

  // 권한 전달 (뜻은 [PlanEntitlements] 각 필드)
  bool get isPro => entitlements.isPro;
  bool get canExportCardsWithoutWatermark => entitlements.canExportCardsWithoutWatermark;
  bool get canUseAllCardDesignThemes => entitlements.canUseAllCardDesignThemes;
  bool get canViewWeeklyReport => entitlements.canViewWeeklyReport;
  bool get canTranslateRoutines => entitlements.canTranslateRoutines;
  bool get canScheduleRoutines => entitlements.canScheduleRoutines;
  bool get canUseGuardianVoice => entitlements.canUseGuardianVoice;
  bool get canImportExpertRoutines => entitlements.canImportExpertRoutines;
  bool get canUseRoutineMemory => entitlements.canUseRoutineMemory;
  bool get canRegenerateImagesFree => entitlements.canRegenerateImagesFree;
  bool get canUseAiPictures => entitlements.canUseAiPictures;

  /// Pro 기능 자리에 흐린 미리 보기(`ProTeaser`)를 보이는가: Free + 앱에서 Pro 를 살 수 있음
  /// Pro 인데 권한이 꺼진 기능(운영이 막아 둔 것)에는 권유하지 않는다
  bool get shouldShowProTeaser => !isPro && canPurchasePro;

  /// Pro 기능 입구(설정 줄·메뉴)를 보이는가: 쓸 수 있음 또는 흐린 미리 보기 대상
  bool shouldShowEntryFor({required bool canUseFeature}) => canUseFeature || shouldShowProTeaser;

  /// 기능 자리에 실제 화면 대신 흐린 미리 보기를 보이는가: 못 씀 + 흐린 미리 보기 대상
  bool shouldShowTeaserFor({required bool canUseFeature}) => !canUseFeature && shouldShowProTeaser;

  /// 일과관리에 `전문가 일과` 입구를 보이는가. 살 수 없는 동안 Free 에게는 숨긴다
  bool get shouldShowExpertRoutines => shouldShowEntryFor(canUseFeature: canImportExpertRoutines);

  /// 같은 권한 판정 + 구매 가능 여부만 바꾼 사본
  PlanAccess withCanPurchasePro(bool canPurchasePro) =>
      PlanAccess(entitlements: entitlements, canPurchasePro: canPurchasePro);
}

/// 지금 계정의 Free·Pro 판정 (회원 조회 중·실패면 Free 로 본다)
final planAccessProvider = Provider<PlanAccess>((ref) {
  return _readPlanAccess(
    ref,
  ).withCanPurchasePro(ref.watch(canPurchaseProProvider));
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
  return PlanAccess(entitlements: member.entitlements);
}
