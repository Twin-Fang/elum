package com.chuseok22.elumserver.license.core;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 스토어 결제 검증 거부 사유 > 앱에 주는 에러 코드 (사유는 로그·거래 이력에 그대로 남김)
 */
@Getter
@AllArgsConstructor
public enum StoreVerifyRejectReason {

  /// 서명·인증서 체인 불일치 (위조·변조)
  SIGNATURE_INVALID(ErrorCode.SUBSCRIPTION_RECEIPT_INVALID),
  /// 빈 값·형식 오류·영수증 간 불일치
  MALFORMED(ErrorCode.SUBSCRIPTION_RECEIPT_INVALID),
  /// 다른 앱(번들 ID·패키지명)의 결제
  APP_MISMATCH(ErrorCode.SUBSCRIPTION_RECEIPT_INVALID),
  /// 자동 갱신 구독이 아닌 결제
  NOT_SUBSCRIPTION(ErrorCode.SUBSCRIPTION_RECEIPT_INVALID),
  /// 소모성 상품이 아닌 결제 (크레딧 구매 확인에 구독 거래가 온 경우)
  NOT_CONSUMABLE(ErrorCode.SUBSCRIPTION_RECEIPT_INVALID),
  /// 스토어에 없는 구매 (토큰 오류·다른 환경)
  PURCHASE_NOT_FOUND(ErrorCode.SUBSCRIPTION_RECEIPT_INVALID),
  /// 테스트 결제인데 테스트 결제 허용이 꺼짐
  ENVIRONMENT_NOT_ALLOWED(ErrorCode.SUBSCRIPTION_ENVIRONMENT_NOT_ALLOWED),
  /// 허용 상품 목록에 없는 상품
  PRODUCT_NOT_ALLOWED(ErrorCode.SUBSCRIPTION_PRODUCT_NOT_ALLOWED),
  /// 다른 회원에 묶인 구매 (구매 복원을 다른 계정에서 시도)
  OWNED_BY_OTHER_MEMBER(ErrorCode.SUBSCRIPTION_OWNED_BY_OTHER_MEMBER),
  ;

  private final ErrorCode errorCode;
}
