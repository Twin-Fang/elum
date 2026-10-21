package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 의견 상세 "보낸 회원" 패널: 표시 이름, 요금제, 회원 상태, 크레딧 요약, 의견 시각 기준 최근 AI 호출
 * 상태 3개: 불러옴(isMemberFound), 회원 없음(완전 삭제), 불러오기 실패(isLoadFailed). 도움 방식(supportGoals)은 담지 않음
 *
 * @param creditSummary 탈퇴 회원이면 null (카드 숨김)
 * @param aiCallsUntil  AI 호출 조회 끝 시각 (의견 시각 + 여유 시간)
 */
public record AdminFeedbackSenderPanel(
  boolean isLoadFailed,
  boolean isMemberFound,
  String memberId,
  String displayName,
  MemberStatus status,
  PlanType plan,
  AdminMemberCreditSummary creditSummary,
  List<AiCallLog> recentAiCalls,
  LocalDateTime aiCallsUntil
) {

  /// 모니터링 링크 기간 (조회 끝 날짜 포함 7일)
  private static final int MONITORING_LINK_PERIOD_DAYS = 7;

  /// 회원을 찾을 수 없음 (탈퇴 후 완전 삭제 등)
  public static AdminFeedbackSenderPanel memberNotFound(String memberId) {
    return new AdminFeedbackSenderPanel(false, false, memberId, null, null, null, null, List.of(), null);
  }

  /// 조회 실패 (패널에 안내만, 의견 본문은 그대로)
  public static AdminFeedbackSenderPanel loadFailed(String memberId) {
    return new AdminFeedbackSenderPanel(true, false, memberId, null, null, null, null, List.of(), null);
  }

  /// 회원 상세 링크를 걸 수 있는가 (회원 없음이 확인된 때만 숨김, 조회 실패는 링크 유지)
  public boolean canOpenMemberDetail() {
    return isLoadFailed || isMemberFound;
  }

  public boolean isWithdrawn() {
    return status == MemberStatus.WITHDRAWN;
  }

  /// 모니터링 링크 시작일·종료일 (yyyy-MM-dd 로 그대로 넘김)
  public LocalDate monitoringFromDate() {
    return aiCallsUntil == null ? null : aiCallsUntil.toLocalDate().minusDays(MONITORING_LINK_PERIOD_DAYS - 1L);
  }

  public LocalDate monitoringToDate() {
    return aiCallsUntil == null ? null : aiCallsUntil.toLocalDate();
  }
}
