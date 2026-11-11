import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../credit/domain/credit_purchase.dart';

/// 크레딧 구매 단계. 전이는 아래 메서드 한 곳 (구매 코디네이터만 부름)
class CreditPurchaseNotifier extends Notifier<CreditPurchaseState> {
  @override
  CreditPurchaseState build() => CreditPurchaseState.idle;

  /// 결제 시작 요청: 새 결제를 해도 되면 진행 중으로 바꾸고 true (두 번 결제 방지)
  bool begin() {
    if (!state.canStartPurchase) return false;
    _set(const CreditPurchaseState(CreditPurchasePhase.busy));
    return true;
  }

  /// 서버 확인 중 (결제 흐름 밖에서 온 남은 구매 확인도 화면을 막음)
  void startVerifying() => _set(const CreditPurchaseState(CreditPurchasePhase.busy));

  /// 결제창에서 닫음 (안내 없이 원래 화면). 확인 중이면 그대로
  void canceled() {
    if (state.phase == CreditPurchasePhase.busy) _set(CreditPurchaseState.idle);
  }

  /// 결제는 됐는데 서버가 아직 안 넣음 > 다시 결제 없이 `다시 확인하기`
  void needsRecheck({Object? failure, String? failureCode}) =>
      _set(CreditPurchaseState(CreditPurchasePhase.needsRecheck, failure: failure, failureCode: failureCode));

  /// 서버가 크레딧을 넣음
  void granted(int credits) => _set(CreditPurchaseState(CreditPurchasePhase.granted, grantedCredits: credits));

  /// 다시 해도 같은 결과인 실패
  void failed(Object? failure, String failureCode) =>
      _set(CreditPurchaseState(CreditPurchasePhase.failed, failure: failure, failureCode: failureCode));

  /// 확인할 것이 없거나 이미 넣은 거래 > 안내 없이 고르는 상태로
  void settledSilently() => _set(CreditPurchaseState.idle);

  /// 안내(알림 띠 · 실패 팝업)를 띄운 뒤 고르는 상태로
  void acknowledged() {
    if (state.phase == CreditPurchasePhase.granted || state.phase == CreditPurchasePhase.failed) {
      _set(CreditPurchaseState.idle);
    }
  }

  void _set(CreditPurchaseState next) {
    if (next == state) return;
    AppLogger.info('[credit purchase] ${state.phase.name} -> ${next.phase.name}');
    state = next;
  }
}

final creditPurchaseStateProvider =
    NotifierProvider<CreditPurchaseNotifier, CreditPurchaseState>(CreditPurchaseNotifier.new);
