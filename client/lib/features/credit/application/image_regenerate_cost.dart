import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/credit_repository.dart';

/// 카드 그림 새로 그리기 1장에 드는 값: 오늘 남은 무료 다시 그리기(Pro) · 다시 그리기 단가 · 처음 그리기(카드 그림) 단가 · 크레딧 켜짐
typedef ImageRegenerateCost = ({int freeLeftToday, int credits, int firstPictureCredits, bool isCreditEnabled});

/// 다시 그리기 확인 시트가 보는 값 (크레딧 요약에서 꺼냄). 실패하면 시트가 "크레딧을 써요"로 그림
///
/// 다른 기능이 credit 의 data 를 직접 알지 않게 하는 입구 (tool/check_layer_imports.dart)
final imageRegenerateCostProvider = FutureProvider.autoDispose<ImageRegenerateCost>((ref) async {
  final summary = await ref.watch(creditSummaryProvider.future);
  return (
    freeLeftToday: summary.enabled ? summary.freeImageRegeneratesLeftToday : 0,
    credits: summary.enabled ? summary.imageRegenerateCost : 0,
    firstPictureCredits: summary.enabled ? summary.cardImageCost : 0,
    isCreditEnabled: summary.enabled,
  );
}, retry: (_, _) => null);
