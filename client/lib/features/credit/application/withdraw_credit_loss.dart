import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/credit_repository.dart';
import '../domain/credit_breakdown.dart';

/// 회원탈퇴로 사라지는 크레딧: 남은 전체 · 그중 결제로 산 것
typedef WithdrawCreditLoss = ({int available, int purchased});

/// 탈퇴 경고에 적을 크레딧 (#1303). 크레딧이 꺼졌거나 남은 게 없으면 null > 줄 숨김
///
/// 조회 실패는 던짐 > 호출부가 숫자 없는 문구로 대신함
final withdrawCreditLossProvider = FutureProvider.autoDispose<WithdrawCreditLoss?>((ref) async {
  final summary = await ref.watch(creditSummaryProvider.future);
  if (!summary.enabled || summary.available <= 0) return null;
  final purchased = summary.breakdown
      .where((line) => line.kind == CreditKind.purchased)
      .fold<int>(0, (sum, line) => sum + line.remaining);
  return (available: summary.available, purchased: purchased);
});

/// 탈퇴 경고용 크레딧 조회 결과: 알았는가 + 사라지는 크레딧 (모르면 숫자 없는 문구)
typedef WithdrawCreditLossLookup = ({bool isKnown, WithdrawCreditLoss? loss});

// 탈퇴 경고를 오래 막지 않는 조회 한도 (넘기면 숫자 없는 문구)
const _lookupTimeout = Duration(seconds: 3);

/// 탈퇴 경고 직전 크레딧 조회 (최대 3초). 실패·시간 초과 > isKnown false
Future<WithdrawCreditLossLookup> readWithdrawCreditLoss(WidgetRef ref) async {
  // 조회 동안 autoDispose 가 풀리지 않게 잡아 둠 (성공·실패 공통으로 놓음)
  final keepAlive = ref.listenManual(withdrawCreditLossProvider, (_, _) {});
  try {
    final loss = await ref.read(withdrawCreditLossProvider.future).timeout(_lookupTimeout);
    return (isKnown: true, loss: loss);
  } catch (error, stack) {
    AppLogger.error('[withdraw credit] lookup failed', error, stack);
    return (isKnown: false, loss: null);
  } finally {
    keepAlive.close();
  }
}
