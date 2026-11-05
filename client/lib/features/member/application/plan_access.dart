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
    required this.canUseGuardianVoice,
    required this.canImportExpertRoutines,
    required this.canUseRoutineMemory,
    required this.canRegenerateImagesFree,
    required this.canUseAiPictures,
    this.canPurchasePro = false,
  });

  /// 모르거나 Free 일 때 (워터마크 넣음 · 기본 테마만 · Pro 기능 전부 꺼짐)
  static const free = PlanAccess(
    isPro: false,
    canExportCardsWithoutWatermark: false,
    canUseAllCardDesignThemes: false,
    canViewWeeklyReport: false,
    canTranslateRoutines: false,
    canScheduleRoutines: false,
    canUseGuardianVoice: false,
    canImportExpertRoutines: false,
    canUseRoutineMemory: false,
    canRegenerateImagesFree: false,
    canUseAiPictures: false,
  );

  /// 개발자 도구 `Pro 처럼`
  static const pro = PlanAccess(
    isPro: true,
    canExportCardsWithoutWatermark: true,
    canUseAllCardDesignThemes: true,
    canViewWeeklyReport: true,
    canTranslateRoutines: true,
    canScheduleRoutines: true,
    canUseGuardianVoice: true,
    canImportExpertRoutines: true,
    canUseRoutineMemory: true,
    canRegenerateImagesFree: true,
    canUseAiPictures: true,
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

  /// 카드마다 보호자 목소리를 녹음할 수 있는가. 꺼져도 이미 한 녹음은 남고(듣기·지우기 가능) 이룸이는 기본 음성으로 듣는다
  final bool canUseGuardianVoice;

  /// 전문가 일과를 일과관리로 가져올 수 있는가
  final bool canImportExpertRoutines;

  /// 이룸이별 AI 메모(내가 고친 일과처럼 만들기)를 쓸 수 있는가
  final bool canUseRoutineMemory;

  /// 카드 그림 다시 그리기가 크레딧 없이 되는가 (하루 한도를 넘으면 서버가 원래 단가로 받음)
  final bool canRegenerateImagesFree;

  /// AI 맞춤 그림을 쓸 수 있는가: 카드 `다시 그리기`·`AI 그림 그리기`. 꺼지면 그 자리에 Pro 안내 (이미 만든 그림은 그대로)
  final bool canUseAiPictures;

  /// Pro 기능 자리에 흐린 미리 보기(`ProTeaser`)를 보이는가: Free + 앱에서 Pro 를 살 수 있음
  /// Pro 인데 권한이 꺼진 기능(운영이 막아 둔 것)에는 권유하지 않는다
  bool get shouldShowProTeaser => !isPro && canPurchasePro;

  /// 일과관리에 `전문가 일과` 입구를 보이는가. 살 수 없는 동안 Free 에게는 숨긴다
  bool get shouldShowExpertRoutines => canImportExpertRoutines || shouldShowProTeaser;

  /// 같은 권한 판정 + 구매 가능 여부만 바꾼 사본 (필드를 더하면 여기 한 곳만 고친다)
  PlanAccess withCanPurchasePro(bool canPurchasePro) => PlanAccess(
    isPro: isPro,
    canExportCardsWithoutWatermark: canExportCardsWithoutWatermark,
    canUseAllCardDesignThemes: canUseAllCardDesignThemes,
    canViewWeeklyReport: canViewWeeklyReport,
    canTranslateRoutines: canTranslateRoutines,
    canScheduleRoutines: canScheduleRoutines,
    canUseGuardianVoice: canUseGuardianVoice,
    canImportExpertRoutines: canImportExpertRoutines,
    canUseRoutineMemory: canUseRoutineMemory,
    canRegenerateImagesFree: canRegenerateImagesFree,
    canUseAiPictures: canUseAiPictures,
    canPurchasePro: canPurchasePro,
  );
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
  return PlanAccess(
    isPro: member.isPro,
    canExportCardsWithoutWatermark: member.canExportCardsWithoutWatermark,
    canUseAllCardDesignThemes: member.canUseAllCardDesignThemes,
    canViewWeeklyReport: member.canViewWeeklyReport,
    canTranslateRoutines: member.canTranslateRoutines,
    canScheduleRoutines: member.canScheduleRoutines,
    canUseGuardianVoice: member.canUseGuardianVoice,
    canImportExpertRoutines: member.canImportExpertRoutines,
    canUseRoutineMemory: member.canUseRoutineMemory,
    canRegenerateImagesFree: member.canRegenerateImagesFree,
    canUseAiPictures: member.canUseAiPictures,
  );
}
