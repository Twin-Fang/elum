import 'package:flutter/foundation.dart';

import '../../member/domain/member_subscription.dart';

/// 서버 결제 확인 결과 3개 — `SubscriptionVerifyResponse.verification`
enum StoreVerification {
  /// Pro 이용 중
  active('ACTIVE'),

  /// 확인됐지만 Pro 아님 (만료·환불·결제 대기)
  inactive('INACTIVE'),

  /// 스토어 확인 중. Pro 를 아직 주지 않았고 거래를 마무리하지 않는다
  pending('PENDING');

  const StoreVerification(this.wire);

  final String wire;

  /// 모르는 값이면 null > 호출부가 실패로 본다 (거래를 마무리하지 않는다)
  static StoreVerification? tryParse(Object? raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return null;
  }

  /// 서버가 이 구매를 처리 끝냈는가 > 스토어 거래를 마무리해도 되는가
  bool get isSettled => this != pending;
}

/// 결제 확인 응답: 결과 + 반영 후 요금제 상태
@immutable
class StoreVerificationResult {
  const StoreVerificationResult({
    required this.verification,
    this.subscription,
  });

  final StoreVerification verification;
  final MemberSubscription? subscription;
}
