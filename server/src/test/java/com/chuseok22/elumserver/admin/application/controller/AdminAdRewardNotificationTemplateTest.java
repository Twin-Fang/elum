package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminAdRewardDetail;
import com.chuseok22.elumserver.admin.application.dto.response.AdminAdRewardRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminAdRewardTimelineEvent;
import com.chuseok22.elumserver.admin.application.dto.response.AdminNotificationMemberSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminNotificationMemberSummary.TypeSwitch;
import com.chuseok22.elumserver.admin.application.dto.response.AdminNotificationRow;
import com.chuseok22.elumserver.admin.application.list.AdminAdRewardList;
import com.chuseok22.elumserver.admin.application.list.AdminListPeriod;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminNotificationList;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardSessionAdminView;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardStatusSummary;
import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.entity.AdRewardSession;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationAdminView;
import com.chuseok22.elumserver.notification.core.NotificationType;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 광고 보상·알림 기록 화면이 실제로 그려지는지 (#910)
 * 식 하나가 틀리면 그 화면은 500 인데 컴파일로는 안 잡힌다. 템플릿 엔진만으로 그려 본다
 */
class AdminAdRewardNotificationTemplateTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 21, 12, 0);
  private static final String NONCE = "nonceABCDEFsecretrest";
  private static final String TRANSACTION_ID = "txn123456789secret";

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  private static AdRewardSession session(
    String id, AdRewardStatus status, AdRewardRejectReason reason, LocalDateTime expiresAt
  ) {
    AdRewardSession session = new AdRewardSession();
    ReflectionTestUtils.setField(session, "id", id);
    session.setMemberId("member-1");
    session.setNonce(NONCE);
    session.setStatus(status);
    session.setRejectReason(reason);
    session.setExpiresAt(expiresAt);
    ReflectionTestUtils.setField(session, "createdAt", NOW.minusMinutes(30));
    ReflectionTestUtils.setField(session, "updatedAt", NOW.minusMinutes(25));
    if (status == AdRewardStatus.GRANTED) {
      session.setGrantedAt(NOW.minusMinutes(25));
      session.setGrantedCredits(2);
      session.setTransactionId(TRANSACTION_ID);
      session.setGrantId("grant-1");
    }
    return session;
  }

  private static AdminAdRewardRow row(AdRewardSession session) {
    return AdminAdRewardRow.of(AdRewardSessionAdminView.of(session, NOW), "보호자닉");
  }

  private String renderList(Map<String, String> filters, List<AdminAdRewardRow> rows, boolean hasSummary) {
    AdminListQuery query = AdminListPeriod.withCorrectedPeriod(
      AdminListQuery.of(null, filters, null, null, AdminAdRewardList.DEFINITION), NOW.toLocalDate());
    AdRewardStatusSummary summary = new AdRewardStatusSummary(3, 1, 0, 2, 6);
    Map<String, Object> model = new HashMap<>();
    model.put("sessions", new PageImpl<>(rows, PageRequest.of(0, 50), rows.size()));
    model.put("isMemberSearchTruncated", false);
    model.put("todaySummary", hasSummary ? summary : null);
    model.put("periodSummary", hasSummary ? summary : null);
    model.put("statusOptions", AdminAdRewardList.STATUS_OPTIONS);
    model.put("reasonOptions", AdminAdRewardList.REASON_OPTIONS);
    model.put("definition", AdminAdRewardList.DEFINITION);
    model.put("query", query);
    model.put("pagerBaseUrl", "/admin/ad-rewards" + query.toQueryString(query.sort(), 1));
    return renderer.render("admin/ad-rewards", model);
  }

  @Test
  @DisplayName("광고 보상 목록: 거절 사유와 '콜백이 오지 않음'이 보여 제보 원인을 바로 가른다")
  void listShowsRejectReasonAndMissingCallback() {
    String html = renderList(Map.of(), List.of(
      row(session("s-rejected", AdRewardStatus.REJECTED, AdRewardRejectReason.DAILY_LIMIT, NOW.plusMinutes(5))),
      row(session("s-stale", AdRewardStatus.PENDING, null, NOW.minusMinutes(1))),
      row(session("s-granted", AdRewardStatus.GRANTED, null, NOW.plusMinutes(5)))), true);

    assertThat(html).contains("data-ad-reward-today", "오늘 횟수 다 씀", "text-error",
      AdminAdRewardList.NO_CALLBACK_LABEL, "+2", "/admin/ad-rewards/s-rejected", "/admin/members/member-1",
      "/admin/ad-rewards?status=REJECTED");
    // 콜백 없이 지난 대기 세션은 '대기'가 아니라 '만료'로 보인다
    assertThat(html).contains("data-ad-reward-status>만료").doesNotContain("data-ad-reward-status>대기");
    // 목록에는 nonce 원문을 내지 않는다
    assertThat(html).doesNotContain(NONCE);
  }

  @Test
  @DisplayName("광고 보상 목록: 요약 조회가 실패해도 목록은 그려지고 오류 코드가 보인다")
  void listRendersWithoutSummary() {
    String html = renderList(Map.of("status", "GRANTED"), List.of(), false);

    assertThat(html).contains("ADMIN-AD-REWARD-SUMMARY", "조건에 맞는 세션이 없어요")
      .doesNotContain("data-ad-reward-today");
  }

  @Test
  @DisplayName("광고 보상 상세: nonce·transaction id 는 앞 6자만 보이고 원문은 화면에 없다")
  void detailMasksSecretsAndLinksCreditLedger() {
    AdminAdRewardRow granted = row(session("s-granted", AdRewardStatus.GRANTED, null, NOW.plusMinutes(5)));
    AdminAdRewardDetail detail = new AdminAdRewardDetail(granted, List.of(
      new AdminAdRewardTimelineEvent(NOW.minusMinutes(30), "세션 생성", "설명", "neutral", false),
      new AdminAdRewardTimelineEvent(NOW.minusMinutes(25), "지급", "크레딧 2개를 줬어요", "success", false)));

    String html = renderer.render("admin/ad-reward-detail", Map.of("detail", detail));

    assertThat(html).contains("nonceA…", "txn123…", "/admin/credits/members/member-1", "data-ad-reward-timeline",
      "크레딧 2개를 줬어요", "badge-success")
      .doesNotContain(NONCE, TRANSACTION_ID);
  }

  @Test
  @DisplayName("광고 보상 상세: 콜백 없이 만료된 세션은 '받지 않음'과 유효 시간 끝 경고가 보인다")
  void detailShowsMissingCallback() {
    AdminAdRewardRow stale = row(session("s-stale", AdRewardStatus.PENDING, null, NOW.minusMinutes(1)));
    AdminAdRewardDetail detail = new AdminAdRewardDetail(stale, List.of(
      new AdminAdRewardTimelineEvent(NOW.minusMinutes(1), "유효 시간 끝", "콜백이 오지 않았어요", "warning", false)));

    String html = renderer.render("admin/ad-reward-detail", Map.of("detail", detail));

    assertThat(html).contains("만료", "받지 않음 (유효 시간 안에 오지 않았어요)", "badge-warning", "유효 시간 끝");
  }

  private String renderNotifications(String memberId, AdminNotificationMemberSummary summary,
    List<AdminNotificationRow> rows) {
    Map<String, String> filters = new HashMap<>();
    if (memberId != null) {
      filters.put("memberId", memberId);
    }
    AdminListQuery query = AdminListPeriod.withCorrectedPeriod(
      AdminListQuery.of(null, filters, null, null, AdminNotificationList.DEFINITION), LocalDate.of(2026, 10, 21));
    Map<String, Object> model = new HashMap<>();
    model.put("notifications", new PageImpl<>(rows, PageRequest.of(0, 50), rows.size()));
    model.put("isMemberSearchTruncated", false);
    model.put("selectedMemberId", memberId);
    model.put("memberSummary", summary);
    model.put("typeOptions", AdminNotificationList.TYPE_OPTIONS);
    model.put("definition", AdminNotificationList.DEFINITION);
    model.put("query", query);
    model.put("pagerBaseUrl", "/admin/notifications" + query.toQueryString(query.sort(), 1));
    return renderer.render("admin/notifications", model);
  }

  @Test
  @DisplayName("알림 기록: 회원 설정 카드와, 지금 설정으로 푸시가 안 나가는 종류에 '푸시 꺼짐'이 보인다")
  void notificationsShowMemberSettingAndPushOffBadge() {
    AdminNotificationMemberSummary summary = new AdminNotificationMemberSummary("member-1", "보호자닉", 3, true, true,
      List.of(new TypeSwitch(NotificationType.ROUTINE_COMPLETED.name(), "일과 완료", false, false),
        new TypeSwitch(NotificationType.CREDIT_REFILLED.name(), "크레딧 충전", true, true)));
    NotificationAdminView routineCompleted = new NotificationAdminView("n-1", "member-1",
      NotificationType.ROUTINE_COMPLETED, "profile-1", "routine-1", 2, NOW.minusDays(1), NOW, null);

    String html = renderNotifications("member-1", summary,
      List.of(AdminNotificationRow.of(routineCompleted, "보호자닉")));

    assertThat(html).contains("data-notification-member-summary", "안 읽음 3건", "일과 완료 꺼짐", "크레딧 충전 켜짐",
      "실제로 푸시가 나가는 종류 1 / 2", "푸시 꺼짐", "/admin/members/member-1", "/admin/ad-rewards?memberId=member-1",
      "2번", "안 읽음");
  }

  @Test
  @DisplayName("알림 기록: 회원 요약 조회가 실패해도 목록 빈 상태와 오류 코드가 그려진다")
  void notificationsRenderWithoutMemberSummary() {
    String html = renderNotifications("member-1", null, List.of());

    assertThat(html).contains("ADMIN-NOTIFICATION-SUMMARY", "조건에 맞는 알림이 없어요")
      .doesNotContain("data-notification-member-summary");
  }
}
