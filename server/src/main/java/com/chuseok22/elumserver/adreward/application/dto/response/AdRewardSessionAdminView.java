package com.chuseok22.elumserver.adreward.application.dto.response;

import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.entity.AdRewardSession;
import java.time.LocalDateTime;

/**
 * 관리자 조회용 세션 한 건: 저장 상태 + 보이는 상태(콜백 없이 만료된 PENDING > EXPIRED) + 콜백 수신 시각
 * nonce·transactionId 는 원문 그대로 담는다 (가리는 일은 화면 쪽 몫)
 *
 * @param callbackReceivedAt 지급이면 지급 시각, 거절·늦은 콜백이면 상태가 바뀐 시각, 콜백이 없었으면 null
 */
public record AdRewardSessionAdminView(
  String id,
  String memberId,
  AdRewardStatus storedStatus,
  AdRewardStatus effectiveStatus,
  AdRewardRejectReason rejectReason,
  LocalDateTime createdAt,
  LocalDateTime expiresAt,
  LocalDateTime callbackReceivedAt,
  LocalDateTime grantedAt,
  int grantedCredits,
  String grantId,
  String nonce,
  String transactionId
) {

  /// 세션 > 관리자 조회용 (now 기준으로 만료 여부 판정)
  public static AdRewardSessionAdminView of(AdRewardSession session, LocalDateTime now) {
    boolean isStalePending = session.getStatus() == AdRewardStatus.PENDING && session.isExpiredAt(now);
    return new AdRewardSessionAdminView(
      session.getId(), session.getMemberId(), session.getStatus(),
      isStalePending ? AdRewardStatus.EXPIRED : session.getStatus(),
      session.getRejectReason(), session.getCreatedAt(), session.getExpiresAt(),
      callbackReceivedAtOf(session), session.getGrantedAt(), session.getGrantedCredits(), session.getGrantId(),
      session.getNonce(), session.getTransactionId());
  }

  /// 콜백을 한 번이라도 받아 상태가 바뀌었는지 (PENDING 그대로면 콜백 없음 또는 거른 콜백만 옴)
  public boolean hasCallback() {
    return storedStatus != AdRewardStatus.PENDING;
  }

  /// 콜백 없이 유효 시간이 지난 세션
  public boolean isExpiredWithoutCallback() {
    return storedStatus == AdRewardStatus.PENDING && effectiveStatus == AdRewardStatus.EXPIRED;
  }

  // 콜백 수신 시각: 지급 > 지급 시각, 그 밖의 끝난 상태 > 마지막 변경 시각 (콜백만 상태를 바꿈)
  private static LocalDateTime callbackReceivedAtOf(AdRewardSession session) {
    if (session.getStatus() == AdRewardStatus.GRANTED) {
      return session.getGrantedAt();
    }
    return session.getStatus() == AdRewardStatus.PENDING ? null : session.getUpdatedAt();
  }
}
