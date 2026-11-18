package com.chuseok22.elumserver.admin.infrastructure.repository;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 사용 분석 쿼리 결과 행 모음 (#1436): AdminUsageAnalyticsQueries 가 돌려주는 날것의 숫자
 * 화면 문구·비율 계산은 서비스 몫
 */
public final class AdminUsageAnalyticsRows {

  private AdminUsageAnalyticsRows() {
  }

  /** 가입 단계 5개 인원: 가입 > 일과 만듦 > 카드 체크 > 기기 연결 > 스토어 결제 */
  public record FunnelCounts(
    long signedUpCount, long routineMadeCount, long cardCheckedCount, long deviceLinkedCount, long storePaidCount
  ) {
  }

  /** 가입 주 하나: 인원, 1·2·4주 뒤 그 주에 방문한 인원 */
  public record RetentionCohortCounts(
    LocalDate cohortWeekStart, long cohortSize, long week1ReturnedCount, long week2ReturnedCount,
    long week4ReturnedCount
  ) {
  }

  /** 첫날 한 일 묶음 하나 (#1471): 묶음 key(AdminFirstDayActivationKind 이름), 인원, 7일 재방문 대상·인원 */
  public record FirstDayActivationCounts(String activationKind, long memberCount, long maturedCount, long retainedCount) {
  }

  /** 주별 추이 한 칸: 줄 key(SIGNUPS 등), 주 첫날(월요일), 건수 */
  public record WeeklyCount(String seriesKey, LocalDate weekStart, long total) {
  }

  /** 마지막 활동 분포 5칸: 1일 안, 7일 안, 30일 안, 그 이상, 기록 없음 (탈퇴 제외) */
  public record LastActivityCounts(
    long withinOneDayCount, long withinSevenDaysCount, long withinThirtyDaysCount, long olderCount, long neverCount
  ) {
  }

  /** 푸시 기기 기준 플랫폼별 회원 수 */
  public record PlatformMemberCounts(long iosMemberCount, long androidMemberCount) {
  }

  /** 대시보드 요약 숫자: 이번 주 활성, 7일 리텐션 대상·재방문 인원, 이번 주 카드 체크 */
  public record HeadlineCounts(
    long weeklyActiveCount, long retentionCohortSize, long retainedCount, long cardCheckCount
  ) {
  }

  /** 최근 가입 한 줄 (계정 종류 무관) */
  public record RecentSignupRow(
    String memberId, String nickname, LocalDateTime createdAt, String loginProviders, long routineCount,
    boolean hasLinkedDevice, LocalDateTime lastActivityAt, String accountKind
  ) {
  }

  /** 최근 활동 한 줄: 종류(SIGNUP 등), 회원, 시각, 묶인 건수 (일과 원문·제목 없음) */
  public record RecentActivityRow(
    String activityKind, String memberId, String nickname, LocalDateTime occurredAt, long itemCount
  ) {
  }

  /** 분류 제안 후보: 규칙 판단 재료 (일반·미확인·탈퇴 아님) */
  public record SuggestionCandidate(
    String memberId, String nickname, LocalDateTime createdAt, String adminMemo, boolean hasAppleLogin,
    boolean hasPrivateRelayEmail, long userRoutineCount, long visitDayCount
  ) {
  }
}
