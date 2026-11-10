import 'package:flutter/foundation.dart';

/// 서버 구매 확인 결과 3개
enum CreditPurchaseStatus {
  /// 이번에 크레딧을 넣음
  granted('GRANTED'),

  /// 이미 넣은 거래 (같은 결제가 다시 옴)
  alreadyGranted('ALREADY_GRANTED'),

  /// 스토어 확인 중 (아직 안 넣음, 거래를 마무리하지 않음)
  pending('PENDING');

  const CreditPurchaseStatus(this.wire);

  final String wire;

  static CreditPurchaseStatus? tryParse(Object? raw) {
    for (final status in values) {
      if (status.wire == raw) return status;
    }
    return null;
  }

  /// 서버가 처리를 끝냈는가 (스토어 거래를 마무리해도 됨)
  bool get isSettled => this != pending;
}

/// 구매 확인 응답: 결과 + 이번에 받은 개수 + 반영 후 잔액
@immutable
class CreditPurchaseResult {
  const CreditPurchaseResult({required this.status, this.grantedCredits = 0, this.available});

  final CreditPurchaseStatus status;
  final int grantedCredits;
  final int? available;
}

/// 크레딧 구매 단계 5개
enum CreditPurchasePhase {
  /// 고르는 중
  idle,

  /// 스토어 결제창 · 서버 확인 중 (새 결제를 막음)
  busy,

  /// 결제는 됐는데 서버가 아직 안 넣음 (대기 · 연결 실패). 다시 결제 없이 `다시 확인하기`
  needsRecheck,

  /// 넣음 (알림 띠를 한 번 띄움)
  granted,

  /// 다시 해도 같은 결과인 실패 (스토어 실패 · 서버 거부). 팝업 한 번
  failed,
}

/// 구매 단계 + 받은 개수 + 실패 원인
@immutable
class CreditPurchaseState {
  const CreditPurchaseState(this.phase, {this.grantedCredits = 0, this.failure, this.failureCode});

  static const idle = CreditPurchaseState(CreditPurchasePhase.idle);

  final CreditPurchasePhase phase;
  final int grantedCredits;
  final Object? failure;
  final String? failureCode;

  bool get isBusy => phase == CreditPurchasePhase.busy;

  /// 새 결제를 시작해도 되는가 (결제됐는데 확인 전이면 다시 결제시키지 않음)
  bool get canStartPurchase =>
      phase == CreditPurchasePhase.idle ||
      phase == CreditPurchasePhase.failed ||
      phase == CreditPurchasePhase.granted;

  @override
  bool operator ==(Object other) =>
      other is CreditPurchaseState &&
      other.phase == phase &&
      other.grantedCredits == grantedCredits &&
      other.failure == failure &&
      other.failureCode == failureCode;

  @override
  int get hashCode => Object.hash(phase, grantedCredits, failure, failureCode);
}

/// 화면 에러 코드 (서버 코드가 없을 때 배지에 쓰는 값)
abstract final class CreditPurchaseErrorCode {
  /// 스토어 가격 불러오기 실패
  static const packPrice = 'E-CREDIT-PACK-PRICE';

  /// 꾸러미 목록 불러오기 실패
  static const packList = 'E-CREDIT-PACK-LIST';

  /// 스토어 결제창 실패
  static const store = 'E-CREDIT-STORE';

  /// 서버 구매 확인 실패 (결제는 스토어에 남음)
  static const verify = 'E-CREDIT-VERIFY';

  /// 회원 id 를 몰라 구매를 계정에 묶을 수 없음
  static const account = 'E-CREDIT-ACCOUNT';

  /// 확인 응답 모양이 다름
  static const response = 'E-CREDIT-RESPONSE';
}
