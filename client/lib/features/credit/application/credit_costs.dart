import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../member/application/plan_access.dart';
import '../data/credit_repository.dart';

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
