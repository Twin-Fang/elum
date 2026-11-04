package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.license.core.StorePurchaseEventResult;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchaseEvent;
import java.time.LocalDateTime;

/**
 * 회원 상세의 스토어 거래 이력 한 줄: 시각, 스토어, 계기·종류, 결과·사유, 반영 후 상태·유지 시각, 거래 id 앞부분
 */
public record AdminStorePurchaseEventLine(
  LocalDateTime occurredAt,
  SubscriptionSource store,
  StorePurchaseTrigger trigger,
  String eventType,
  StorePurchaseEventResult result,
  String reason,
  StorePurchaseState stateAfter,
  LocalDateTime expiresAtAfter,
  /// 거래 id 앞 12자 (스토어 콘솔에서 찾을 때 쓰는 정도만)
  String transactionIdPrefix
) {

  private static final int TRANSACTION_ID_PREFIX_LENGTH = 12;

  public static AdminStorePurchaseEventLine from(StorePurchaseEvent event) {
    String transactionId = event.getTransactionId();
    String prefix = transactionId == null || transactionId.length() <= TRANSACTION_ID_PREFIX_LENGTH
      ? transactionId : transactionId.substring(0, TRANSACTION_ID_PREFIX_LENGTH) + "…";
    return new AdminStorePurchaseEventLine(
      event.getOccurredAt(), event.getStore(), event.getTrigger(), event.getEventType(), event.getResult(),
      event.getReason(), event.getStateAfter(), event.getExpiresAtAfter(), prefix);
  }
}
