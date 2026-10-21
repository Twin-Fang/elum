package com.chuseok22.elumserver.admin.application.dto.response;

/**
 * 회원 상세 크레딧 요약 카드: 이번 주 사용 가능·주간 지급·보너스·사용, 동결 여부
 * 상태 3개: 불러옴(hasAccount), 계정 없음, 불러오기 실패(isLoadFailed)
 *
 * @param available   지금 사용 가능량 (남음 − 예약)
 * @param weeklyGrant 이번 주 주간 지급량 (아직 지급 전이면 0)
 * @param bonus       유효한 보너스 남은 양
 * @param used        이번 주 사용량
 */
public record AdminMemberCreditSummary(
  boolean isLoadFailed,
  boolean hasAccount,
  long available,
  long weeklyGrant,
  long bonus,
  long used,
  boolean isFrozen
) {

  /// 크레딧 계정이 아직 없음 (AI 를 한 번도 안 씀)
  public static AdminMemberCreditSummary noAccount() {
    return new AdminMemberCreditSummary(false, false, 0, 0, 0, 0, false);
  }

  /// 조회 실패 (카드에 안내만, 상세 화면은 그대로)
  public static AdminMemberCreditSummary loadFailed() {
    return new AdminMemberCreditSummary(true, false, 0, 0, 0, 0, false);
  }
}
