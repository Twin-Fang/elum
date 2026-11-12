import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../member/application/plan_access.dart';
import '../data/credit_repository.dart';
import '../domain/credit_period_unit.dart';

/// 일과 하나를 만들 때(`routine`)와 카드 그림 한 장마다(`image`) 드는 크레딧.
typedef CreditCosts = ({int routine, int image});

/// 그림 방식 화면의 크레딧 띠가 보는 단가. 크레딧 기능이 꺼져 있으면 null 이다.
///
/// 아직 못 받았거나 조회가 실패하면 기본 단가(1)를 준다. 안내용이라 실패를 화면에
/// 띄우지 않지만 원인을 찾을 수 있게 로그는 남긴다.
final creditCostsProvider = Provider.autoDispose<CreditCosts?>((ref) {
  final async = ref.watch(creditSummaryProvider);
  if (async.hasError) {
    AppLogger.error('creditCostsProvider (조회 실패 — 기본 단가로 그린다)', async.error);
  }
  final summary = async.value;
  if (summary != null && !summary.enabled) return null;
  return (
    routine: summary?.routineTextCost ?? 1,
    image: summary?.cardImageCost ?? 1,
  );
});

/// 크레딧이 다시 채워지는 주기. 아직 못 받았거나 실패하면 주로 본다.
final creditPeriodUnitProvider = Provider.autoDispose<CreditPeriodUnit>(
  (ref) => ref.watch(creditSummaryProvider).value?.periodUnit ?? CreditPeriodUnit.week,
);

/// 일과 만들기 비용 미리 보기(그림 방식 띠)가 보는 단가: 글 무료 권한(Pro)이면 글 0, 그림은 그대로
///
/// 번역 안내는 글 단가를 그대로 써야 해서 [creditCostsProvider] 를 본다 (글 무료는 일과 만들기에만)
final routineCreateCreditCostsProvider = Provider.autoDispose<CreditCosts?>((ref) {
  final costs = ref.watch(creditCostsProvider);
  if (costs == null) return null;
  final canCreateRoutineTextFree = ref.watch(
    planAccessProvider.select((access) => access.canCreateRoutineTextFree),
  );
  return canCreateRoutineTextFree ? (routine: 0, image: costs.image) : costs;
});

/// 무료 다시 그리기 하루 한도 (요금제 혜택 줄 `하루 N번까지`). 모르면(조회 전 · 실패 · 이전 서버 · 0) null > 숫자 없는 문구
final freeImageRegenerateDailyCapProvider = Provider.autoDispose<int?>((ref) {
  final cap = ref.watch(creditSummaryProvider).value?.freeImageRegenerateDailyCap ?? 0;
  return cap > 0 ? cap : null;
});

/// 지금 남은 크레딧 (비용 한 줄 `지금 N개 있어요`). 크레딧이 꺼졌거나 모르면(조회 전 · 실패) null > 줄 숨김
final availableCreditsProvider = Provider.autoDispose<int?>((ref) {
  final summary = ref.watch(creditSummaryProvider).value;
  if (summary == null || !summary.enabled) return null;
  return summary.available;
});

/// 주기마다 받는 크레딧 (온보딩 첫 설명 `매주 N개 받아요`). 크레딧이 꺼졌거나 모르면 null > 숫자 없는 문구
final creditGrantPerPeriodProvider = Provider.autoDispose<int?>((ref) {
  final summary = ref.watch(creditSummaryProvider).value;
  if (summary == null || !summary.enabled || summary.weeklyGrant <= 0) return null;
  return summary.weeklyGrant;
});
