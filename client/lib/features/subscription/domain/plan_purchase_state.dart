import 'package:flutter/foundation.dart';

import 'plan_error_code.dart';
import 'store_verification.dart';

/// 요금제 화면 결제 단계 8개
enum PlanPurchasePhase {
  /// 고르는 중 (결제 버튼 눌림 가능)
  idle,

  /// 스토어 결제창이 떠 있음
  purchasing,

  /// 스토어가 결제를 미룸 (가족 공유 구매 요청 · 결제 수단 확인). 허락되면 스토어가 다시 알림
  waitingForStoreApproval,

  /// 서버에 결제 확인 중
  verifying,

  /// 결제는 됐지만 아직 Pro 를 못 켬 (서버 PENDING · 연결 실패). 다시 결제를 요구하지 않고 다시 확인만
  verificationPending,

  /// Pro 켜짐
  activated,

  /// 서버가 확인했지만 Pro 아님 (결제 대기·환불·만료)
  notActivated,

  /// 다시 해도 같은 결과인 실패 (스토어 실패 · 서버 거부 400). 화면이 팝업 1번 띄우고 [PlanPurchaseEvent.failureShown]
  failed,
}

/// 결제 단계 + 실패 원인 (팝업·배지용)
@immutable
class PlanPurchaseState {
  const PlanPurchaseState._(this.phase, {this.failure, this.failureCode});

  static const idle = PlanPurchaseState._(PlanPurchasePhase.idle);

  final PlanPurchasePhase phase;

  /// 원인 (AppFailure 또는 스토어 오류). 화면은 showFailure 에 그대로 넘김
  final Object? failure;

  /// 서버 코드가 없을 때의 자리 코드 (`E-PLAN-STORE` 등)
  final String? failureCode;

  /// 결제가 진행 중이라 새 결제·닫기를 막아야 하는가
  bool get isBusy =>
      phase == PlanPurchasePhase.purchasing ||
      phase == PlanPurchasePhase.verifying;

  /// 결제 흐름 안인가 (스토어·서버 소식을 화면에 반영할 때)
  bool get isInFlow =>
      phase == PlanPurchasePhase.purchasing ||
      phase == PlanPurchasePhase.waitingForStoreApproval ||
      phase == PlanPurchasePhase.verifying ||
      phase == PlanPurchasePhase.verificationPending;

  /// 새 결제를 시작해도 되는가 (결제됐는데 확인 중이면 다시 결제시키지 않음)
  bool get canStartPurchase =>
      phase == PlanPurchasePhase.idle ||
      phase == PlanPurchasePhase.failed ||
      phase == PlanPurchasePhase.notActivated;

  @override
  bool operator ==(Object other) =>
      other is PlanPurchaseState &&
      other.phase == phase &&
      other.failure == failure &&
      other.failureCode == failureCode;

  @override
  int get hashCode => Object.hash(phase, failure, failureCode);

  @override
  String toString() => 'PlanPurchaseState(${phase.name}, $failureCode)';
}

/// 결제 단계를 바꾸는 사건
sealed class PlanPurchaseEvent {
  const PlanPurchaseEvent();

  /// 보호자가 결제 버튼을 눌러 PIN 까지 통과함
  const factory PlanPurchaseEvent.purchaseRequested() = _PurchaseRequested;

  /// 스토어 결제창에서 취소 (안내 없이 화면 그대로)
  const factory PlanPurchaseEvent.storeCanceled() = _StoreCanceled;

  /// 스토어가 결제를 미룸
  const factory PlanPurchaseEvent.storePending() = _StorePending;

  /// 결제창을 못 띄웠거나 스토어가 실패를 알림. [failureCode] 기본 `E-PLAN-STORE`
  const factory PlanPurchaseEvent.storeFailed(
    Object? error, {
    String failureCode,
  }) = _StoreFailed;

  /// 서버에 확인 요청 보냄
  const factory PlanPurchaseEvent.verificationStarted() = _VerificationStarted;

  /// 서버 확인 결과
  const factory PlanPurchaseEvent.verificationFinished(
    StoreVerification verification,
  ) = _VerificationFinished;

  /// 확인 요청 실패. [isRetryable] 이면 결제는 남아 있으니 다시 확인만 (연결·5xx·꺼짐)
  const factory PlanPurchaseEvent.verificationFailed(
    Object? error, {
    required bool isRetryable,
  }) = _VerificationFailed;

  /// 실패 팝업을 띄움 > 다시 고를 수 있게
  const factory PlanPurchaseEvent.failureShown() = _FailureShown;

  /// 요금제 화면을 닫음 (진행 중이면 그대로 둠)
  const factory PlanPurchaseEvent.dismissed() = _Dismissed;
}

final class _PurchaseRequested extends PlanPurchaseEvent {
  const _PurchaseRequested();
}

final class _StoreCanceled extends PlanPurchaseEvent {
  const _StoreCanceled();
}

final class _StorePending extends PlanPurchaseEvent {
  const _StorePending();
}

final class _StoreFailed extends PlanPurchaseEvent {
  const _StoreFailed(this.error, {this.failureCode = PlanErrorCode.store});
  final Object? error;
  final String failureCode;
}

final class _VerificationStarted extends PlanPurchaseEvent {
  const _VerificationStarted();
}

final class _VerificationFinished extends PlanPurchaseEvent {
  const _VerificationFinished(this.verification);
  final StoreVerification verification;
}

final class _VerificationFailed extends PlanPurchaseEvent {
  const _VerificationFailed(this.error, {required this.isRetryable});
  final Object? error;
  final bool isRetryable;
}

final class _FailureShown extends PlanPurchaseEvent {
  const _FailureShown();
}

final class _Dismissed extends PlanPurchaseEvent {
  const _Dismissed();
}

/// 결제 단계 전이 (순수 함수)
///
/// 규칙 3개
/// - 결제 흐름 밖(고르는 중·끝남)에서 온 스토어·서버 소식은 화면을 바꾸지 않음 (갱신·다른 기기 결제는 조용히 반영)
/// - 결제가 진행 중이면 새 결제 요청을 무시 (두 번 결제 방지)
/// - 결제가 된 뒤의 실패는 "다시 확인"으로만 이어짐 (다시 결제 요구 금지)
PlanPurchaseState reducePlanPurchase(
  PlanPurchaseState state,
  PlanPurchaseEvent event,
) {
  switch (event) {
    case _PurchaseRequested():
      return state.canStartPurchase
          ? const PlanPurchaseState._(PlanPurchasePhase.purchasing)
          : state;
    case _FailureShown():
      return state.phase == PlanPurchasePhase.failed ? PlanPurchaseState.idle : state;
    case _Dismissed():
      // 결제창·확인 요청이 살아 있으면 결과를 받아야 함 > 그대로
      return state.isBusy ? state : PlanPurchaseState.idle;
    case _StoreCanceled():
    case _StorePending():
    case _StoreFailed():
    case _VerificationStarted():
    case _VerificationFinished():
    case _VerificationFailed():
      return state.isInFlow ? _reduceInFlow(state, event) : state;
  }
}

/// 결제 흐름 안에서 스토어·서버 소식 반영
PlanPurchaseState _reduceInFlow(PlanPurchaseState state, PlanPurchaseEvent event) {
  return switch (event) {
    // 결제창에서만 취소가 뜻이 있음 (확인 중에 온 취소는 다른 구매 소식)
    _StoreCanceled() =>
      state.phase == PlanPurchasePhase.purchasing ? PlanPurchaseState.idle : state,
    _StorePending() =>
      state.phase == PlanPurchasePhase.purchasing
          ? const PlanPurchaseState._(PlanPurchasePhase.waitingForStoreApproval)
          : state,
    _StoreFailed(:final error, :final failureCode) =>
      state.phase == PlanPurchasePhase.purchasing
          ? PlanPurchaseState._(
              PlanPurchasePhase.failed,
              failure: error,
              failureCode: failureCode,
            )
          : state,
    _VerificationStarted() =>
      const PlanPurchaseState._(PlanPurchasePhase.verifying),
    _VerificationFinished(:final verification) => switch (verification) {
      StoreVerification.active =>
        const PlanPurchaseState._(PlanPurchasePhase.activated),
      StoreVerification.pending =>
        const PlanPurchaseState._(PlanPurchasePhase.verificationPending),
      StoreVerification.inactive => const PlanPurchaseState._(
        PlanPurchasePhase.notActivated,
        failureCode: PlanErrorCode.inactive,
      ),
    },
    _VerificationFailed(:final error, :final isRetryable) => PlanPurchaseState._(
      isRetryable ? PlanPurchasePhase.verificationPending : PlanPurchasePhase.failed,
      failure: error,
      failureCode: PlanErrorCode.verify,
    ),
    _ => state,
  };
}
