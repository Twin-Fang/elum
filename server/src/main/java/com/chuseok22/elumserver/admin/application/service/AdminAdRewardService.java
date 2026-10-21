package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminAdRewardDetail;
import com.chuseok22.elumserver.admin.application.dto.response.AdminAdRewardRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminAdRewardTimelineEvent;
import com.chuseok22.elumserver.admin.application.list.AdminAdRewardList;
import com.chuseok22.elumserver.admin.application.list.AdminListPaging;
import com.chuseok22.elumserver.admin.application.list.AdminListPeriod;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardSessionAdminView;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardStatusSummary;
import com.chuseok22.elumserver.adreward.application.service.AdRewardAdminQueryService;
import com.chuseok22.elumserver.adreward.application.service.AdRewardSessionSearch;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;

/**
 * 광고 보상 관리자 화면: 세션 목록(회원 조건 > 검색 > 이름 붙이기), 상태 요약, 세션 상세(타임라인)
 * 트랜잭션을 걸지 않는다 — 요약 조회가 실패해도 목록은 그대로 보이게 각 조회를 따로 둔다
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdminAdRewardService {

  private final AdRewardAdminQueryService adRewardAdminQueryService;
  private final AdminMemberFilter adminMemberFilter;

  /// 목록 한 쪽 + 회원 검색이 잘렸는지
  public record SearchResult(Page<AdminAdRewardRow> rows, boolean isMemberSearchTruncated) {

  }

  /// 세션 목록: 회원 조건 > 기간·상태·사유 검색(범위 밖 페이지 보정) > 회원 표시 이름
  public SearchResult search(AdminListQuery query, LocalDateTime now) {
    AdminMemberFilter.Resolved members = adminMemberFilter.resolve(AdminAdRewardList.memberIdOf(query), query.q());
    Page<AdRewardSessionAdminView> sessions = AdminListPaging.fetchWithPageCorrection(query,
      corrected -> adRewardAdminQueryService.search(searchOf(corrected, members, now),
        AdminAdRewardList.pageableOf(corrected)));
    Map<String, String> displayNameById = adminMemberFilter.displayNamesOf(
      sessions.getContent().stream().map(AdRewardSessionAdminView::memberId).distinct().toList());
    return new SearchResult(
      sessions.map(session -> AdminAdRewardRow.of(session, displayNameById.get(session.memberId()))),
      members.isTruncated());
  }

  /// 오늘 만든 세션 요약 (실패하면 비움 — 목록은 그대로 보임)
  public Optional<AdRewardStatusSummary> summarizeToday(LocalDateTime now) {
    LocalDateTime todayStart = now.toLocalDate().atStartOfDay();
    return summarizeSafely(todayStart, todayStart.plusDays(1), now);
  }

  /// 선택한 기간에 만든 세션 요약 (실패하면 비움)
  public Optional<AdRewardStatusSummary> summarizePeriod(AdminListQuery correctedQuery, LocalDateTime now) {
    return summarizeSafely(AdminListPeriod.periodStart(correctedQuery),
      AdminListPeriod.periodEndExclusive(correctedQuery), now);
  }

  /// 세션 상세: 한 건 > 회원 표시 이름 > 타임라인. 없으면 404
  public AdminAdRewardDetail getDetail(String sessionId, LocalDateTime now) {
    AdRewardSessionAdminView session = adRewardAdminQueryService.find(sessionId, now)
      .orElseThrow(() -> new CustomException(ErrorCode.AD_REWARD_SESSION_NOT_FOUND));
    String displayName = adminMemberFilter.displayNamesOf(List.of(session.memberId())).get(session.memberId());
    AdminAdRewardRow row = AdminAdRewardRow.of(session, displayName);
    return new AdminAdRewardDetail(row, timelineOf(row));
  }

  private Optional<AdRewardStatusSummary> summarizeSafely(LocalDateTime from, LocalDateTime to, LocalDateTime now) {
    try {
      return Optional.of(adRewardAdminQueryService.summarize(from, to, now));
    } catch (RuntimeException e) {
      log.warn("[admin ad reward] summary failed : {}", e.getClass().getSimpleName(), e);
      return Optional.empty();
    }
  }

  private static AdRewardSessionSearch searchOf(
    AdminListQuery query, AdminMemberFilter.Resolved members, LocalDateTime now
  ) {
    return new AdRewardSessionSearch(AdminListPeriod.periodStart(query), AdminListPeriod.periodEndExclusive(query),
      members.memberIds(), AdminAdRewardList.statusOf(query), AdminAdRewardList.reasonOf(query), now);
  }

  /**
   * 타임라인: 세션 생성 > (콜백 수신 > 지급·거절·늦은 만료) 또는 (유효 시간 끝: 지남·예정)
   * 서명이 틀렸거나 세션을 못 찾은 콜백은 세션에 남지 않는다 (서버 로그에만)
   */
  private static List<AdminAdRewardTimelineEvent> timelineOf(AdminAdRewardRow row) {
    AdRewardSessionAdminView session = row.session();
    List<AdminAdRewardTimelineEvent> events = new ArrayList<>();
    events.add(new AdminAdRewardTimelineEvent(session.createdAt(), "세션 생성",
      "앱이 광고를 보기 전에 서버에서 세션을 받았어요", "neutral", false));

    // 콜백 없음 (대기·콜백 없이 만료)
    if (!session.hasCallback()) {
      boolean isExpired = session.isExpiredWithoutCallback();
      events.add(new AdminAdRewardTimelineEvent(session.expiresAt(), isExpired ? "유효 시간 끝" : "유효 시간 끝 (예정)",
        isExpired ? "이 시각까지 Google 서버 콜백(SSV)이 오지 않았어요" : "Google 서버 콜백(SSV)을 기다리고 있어요",
        isExpired ? "warning" : "info", !isExpired));
      return events;
    }

    // 콜백 수신 > 결과
    events.add(new AdminAdRewardTimelineEvent(session.callbackReceivedAt(), "콜백 수신",
      "Google 서버 콜백(SSV)의 서명을 확인했어요", "info", false));
    if (session.storedStatus() == AdRewardStatus.GRANTED) {
      events.add(new AdminAdRewardTimelineEvent(session.grantedAt(), "지급",
        "크레딧 " + session.grantedCredits() + "개를 줬어요", "success", false));
    } else if (session.storedStatus() == AdRewardStatus.REJECTED) {
      events.add(new AdminAdRewardTimelineEvent(session.callbackReceivedAt(), "지급 안 함",
        row.reasonLabel() == null ? "사유 기록 없음" : row.reasonLabel(), "error", false));
    } else {
      events.add(new AdminAdRewardTimelineEvent(session.callbackReceivedAt(), "만료",
        "유효 시간이 지난 뒤 도착해 지급하지 않았어요", "warning", false));
    }
    return events;
  }
}
