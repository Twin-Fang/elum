package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.core.ConsumableRefundResult;
import com.chuseok22.elumserver.license.core.StoreRefundOrigin;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 소모성 상품(크레딧 꾸러미) 환불을 받는 쪽: 회수, 환불 취소 재적립, 재확인 대상 거래 목록
 * 알림 수신·검증·재확인 호출은 license, 크레딧 장부는 구현체(credit). 거래 id: Apple transactionId · Google orderId
 */
public interface StoreConsumableRefundHandler {

  /// 그 거래로 준 적립의 남은 양을 회수. 모르는 거래는 스토어 알림일 때만 보류 (구매 확인 때 회수)
  ConsumableRefundOutcome refund(SubscriptionSource store, String transactionId, StoreRefundOrigin origin);

  /// 환불 취소(REFUND_REVERSED): 회수한 양을 다시 적립하거나 보류를 풂
  ConsumableRefundOutcome reverseRefund(SubscriptionSource store, String transactionId);

  /// 재확인 대상: since 이후 적립했고 아직 환불되지 않은 거래 id
  List<String> findGrantedTransactionIds(SubscriptionSource store, LocalDateTime since);

  /// 처리 결과 + 거래의 회원 (모르는 거래면 null, 거래 이력의 회원 칸)
  record ConsumableRefundOutcome(ConsumableRefundResult result, String memberId) {

    public boolean isRevoked() {
      return result == ConsumableRefundResult.REVOKED;
    }
  }
}
