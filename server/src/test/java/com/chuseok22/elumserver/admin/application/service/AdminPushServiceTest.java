package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.request.AdminPushRequest;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushPreviewResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushSendResponse;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminPushOutcome;
import com.chuseok22.elumserver.ai.application.service.AiCallLogQueryService;
import com.chuseok22.elumserver.member.application.service.MemberAdminLookupService;
import com.chuseok22.elumserver.notification.application.service.AdminMessageReach;
import com.chuseok22.elumserver.notification.application.service.AdminMessageSendResult;
import com.chuseok22.elumserver.notification.application.service.AdminMessageService;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.ArgumentCaptor;

/// 대상 계산이 틀리면 엉뚱한 회원에게 가고, 상한·야간 막기가 새면 한밤 대량 발송이 나가며, 기록이 없으면 누가 보냈는지 모른다
class AdminPushServiceTest {

  private static final ZoneId KST = ZoneId.of("Asia/Seoul");
  private static final LocalTime AFTERNOON = LocalTime.of(14, 0);

  private final MemberAdminLookupService memberAdminLookupService = mock(MemberAdminLookupService.class);
  private final AiCallLogQueryService aiCallLogQueryService = mock(AiCallLogQueryService.class);
  private final AdminMessageService adminMessageService = mock(AdminMessageService.class);
  private final AdminAuditService adminAuditService = mock(AdminAuditService.class);

  private AdminPushService serviceAt(LocalTime time) {
    Clock clock = Clock.fixed(LocalDate.of(2026, 11, 12).atTime(time).atZone(KST).toInstant(), KST);
    return new AdminPushService(memberAdminLookupService, aiCallLogQueryService, adminMessageService,
      adminAuditService, clock);
  }

  @Test
  @DisplayName("조건 대상: 그날 포함 가입한 활성 회원 중 AI 호출 N회 이상인 사람만 (다음 날 0시 전으로 묻는다)")
  void preview_condition_intersectsJoinedAndAiUsers() {
    when(memberAdminLookupService.findActiveMemberIdsJoinedBefore(LocalDateTime.of(2026, 11, 1, 0, 0)))
      .thenReturn(List.of("m1", "m2", "m3"));
    when(aiCallLogQueryService.findMemberIdsWithCallCountAtLeast(5)).thenReturn(Set.of("m2", "m3", "m-other"));
    when(adminMessageService.reachOf(anyCollection())).thenReturn(new AdminMessageReach(2, 1, 1));

    AdminPushPreviewResponse preview = serviceAt(AFTERNOON).preview(condition("2026-10-31", 5));

    ArgumentCaptor<List<String>> target = listCaptor();
    verify(adminMessageService).reachOf(target.capture());
    assertThat(target.getValue()).containsExactly("m2", "m3");
    assertThat(preview.outcome()).isEqualTo(AdminPushOutcome.READY.name());
  }

  @Test
  @DisplayName("조건 대상: AI 호출 0 이면 AI 조건을 보지 않는다, 날짜 형식이 틀리면 INVALID_TARGET")
  void preview_condition_zeroMinimumSkipsAi_andBadDateRejected() {
    when(memberAdminLookupService.findActiveMemberIdsJoinedBefore(any())).thenReturn(List.of("m1"));
    when(adminMessageService.reachOf(anyCollection())).thenReturn(new AdminMessageReach(1, 1, 1));

    assertThat(serviceAt(AFTERNOON).preview(condition("2026-10-31", 0)).outcome()).isEqualTo("READY");
    verifyNoInteractions(aiCallLogQueryService);
    assertThat(serviceAt(AFTERNOON).preview(condition("2026/10/31", 0)).outcome()).isEqualTo("INVALID_TARGET");
  }

  @Test
  @DisplayName("1,000명을 넘으면 보내지 않고 기록도 남기지 않는다 (미리 계산은 수를 보여 주며 거절 사유를 단다)")
  void send_overMaximumRecipients_rejectedWithoutSending() {
    List<String> manyMemberIds = IntStream.rangeClosed(1, AdminPushService.MAXIMUM_RECIPIENT_COUNT + 1)
      .mapToObj(index -> "m" + index).toList();
    when(memberAdminLookupService.findActiveMemberIdsJoinedBefore(any())).thenReturn(manyMemberIds);
    when(adminMessageService.reachOf(anyCollection())).thenReturn(new AdminMessageReach(1001, 1001, 900));

    AdminPushSendResponse response = serviceAt(AFTERNOON).send(withMessage(condition("2026-10-31", 0)));
    AdminPushPreviewResponse preview = serviceAt(AFTERNOON).preview(condition("2026-10-31", 0));

    assertThat(response.outcome()).isEqualTo(AdminPushOutcome.TOO_MANY_RECIPIENTS.name());
    assertThat(response.errorCode()).isEqualTo("E-PUSH-002");
    assertThat(preview.outcome()).isEqualTo(AdminPushOutcome.TOO_MANY_RECIPIENTS.name());
    verify(adminMessageService, never()).send(anyString(), anyString(), any(), anyCollection());
    verifyNoInteractions(adminAuditService);
  }

  @Test
  @DisplayName("고른 회원 1,001명은 회원 조회 전에 거절한다 (긴 목록으로 큰 쿼리를 만들지 않게)")
  void send_chosenMembersOverMaximum_rejectedBeforeLookup() {
    List<String> manyMemberIds = IntStream.rangeClosed(1, AdminPushService.MAXIMUM_RECIPIENT_COUNT + 1)
      .mapToObj(index -> "m" + index).toList();

    AdminPushSendResponse response = serviceAt(AFTERNOON).send(withMessage(chosen(manyMemberIds)));

    assertThat(response.outcome()).isEqualTo(AdminPushOutcome.TOO_MANY_RECIPIENTS.name());
    verifyNoInteractions(memberAdminLookupService);
  }

  @ParameterizedTest(name = "{0} > 야간 {1}")
  @CsvSource({"07:59, true", "08:00, false", "20:59, false", "21:00, true", "23:30, true", "00:00, true"})
  @DisplayName("야간 [21:00, 08:00) KST 경계")
  void isQuietHoursNow_boundaries(String time, boolean isQuietHours) {
    assertThat(serviceAt(LocalTime.parse(time)).isQuietHoursNow()).isEqualTo(isQuietHours);
  }

  @Test
  @DisplayName("야간에는 보내기를 막지만, 먼저 보내 보기는 보낸다")
  void quietHours_blocksSend_butAllowsTest() {
    AdminPushService nightService = serviceAt(LocalTime.of(22, 0));
    when(memberAdminLookupService.findActiveMemberIds(List.of("me"))).thenReturn(List.of("me"));
    when(adminMessageService.send(anyString(), anyString(), any(), anyCollection()))
      .thenReturn(new AdminMessageSendResult("msg-test", 1, 1, 0));

    AdminPushSendResponse blocked = nightService.send(withMessage(chosen(List.of("m1"))));
    AdminPushSendResponse test = nightService.sendTest(new AdminPushRequest(null, null, null, null,
      "제목", "본문", "home", "me"));

    assertThat(blocked.outcome()).isEqualTo(AdminPushOutcome.QUIET_HOURS.name());
    assertThat(test.outcome()).isEqualTo(AdminPushOutcome.SENT.name());
    verify(adminMessageService).send("제목", "본문", AdminMessageRoute.HOME, List.of("me"));
    verify(adminAuditService).record(eq(AdminAuditAction.ADMIN_PUSH_TEST_SENT), eq("msg-test"), anyString());
  }

  @Test
  @DisplayName("먼저 보내 보기: 고른 회원이 활성이 아니면 보내지 않는다")
  void sendTest_inactiveMember_rejected() {
    when(memberAdminLookupService.findActiveMemberIds(List.of("suspended"))).thenReturn(List.of());

    AdminPushSendResponse response = serviceAt(AFTERNOON).sendTest(new AdminPushRequest(null, null, null, null,
      "제목", "본문", "home", "suspended"));

    assertThat(response.outcome()).isEqualTo(AdminPushOutcome.TEST_MEMBER_INVALID.name());
    verify(adminMessageService, never()).send(anyString(), anyString(), any(), anyCollection());
  }

  @Test
  @DisplayName("보내기 성공: 활성 회원에게만 보내고, 관리자 기록에 알림 id·대상 수·기기 결과·제목을 남긴다")
  void send_success_recordsAudit() {
    when(memberAdminLookupService.findActiveMemberIds(List.of("m1", "m2", "m-suspended")))
      .thenReturn(List.of("m1", "m2"));
    when(adminMessageService.send(anyString(), anyString(), any(), anyCollection()))
      .thenReturn(new AdminMessageSendResult("msg-1", 2, 3, 1));

    AdminPushSendResponse response = serviceAt(AFTERNOON).send(new AdminPushRequest("MEMBERS",
      List.of("m1", "m2", "m-suspended", "m1"), null, null, "  Pro 선물  ", "고마워요", "plan", null));

    verify(adminMessageService).send("Pro 선물", "고마워요", AdminMessageRoute.PLAN, List.of("m1", "m2"));
    ArgumentCaptor<String> detail = ArgumentCaptor.forClass(String.class);
    verify(adminAuditService).record(eq(AdminAuditAction.ADMIN_PUSH_SENT), eq("msg-1"), detail.capture());
    assertThat(detail.getValue()).isEqualTo("대상 2명 · 기록 2명 · 기기 성공 3 실패 1 · 제목 Pro 선물");
    assertThat(response.recipientCount()).isEqualTo(2);
  }

  @ParameterizedTest(name = "제목 [{0}] 본문 [{1}] 화면 [{2}]")
  @CsvSource(value = {"'', 본문, home", "제목, '   ', home", "제목, 본문, settings", "제목, 본문, ''"})
  @DisplayName("제목·본문이 비었거나 갈 화면을 모르면 INVALID_MESSAGE 로 거절 (보내지 않음)")
  void send_invalidMessage_rejected(String title, String body, String route) {
    AdminPushSendResponse response = serviceAt(AFTERNOON).send(new AdminPushRequest("MEMBERS", List.of("m1"),
      null, null, title, body, route, null));

    assertThat(response.outcome()).isEqualTo(AdminPushOutcome.INVALID_MESSAGE.name());
    verify(adminMessageService, never()).send(anyString(), anyString(), any(), anyCollection());
  }

  @Test
  @DisplayName("제목 51자는 거절한다 (DB 칸 50자를 넘으면 저장이 실패해 500 이 난다)")
  void send_titleOverMaximumLength_rejected() {
    AdminPushSendResponse response = serviceAt(AFTERNOON).send(new AdminPushRequest("MEMBERS", List.of("m1"),
      null, null, "가".repeat(51), "본문", "home", null));

    assertThat(response.outcome()).isEqualTo(AdminPushOutcome.INVALID_MESSAGE.name());
  }

  private static AdminPushRequest condition(String joinedOnOrBefore, int minimumAiCallCount) {
    return new AdminPushRequest("CONDITION", null, joinedOnOrBefore, minimumAiCallCount, null, null, null, null);
  }

  private static AdminPushRequest chosen(List<String> memberIds) {
    return new AdminPushRequest("MEMBERS", memberIds, null, null, null, null, null, null);
  }

  private static AdminPushRequest withMessage(AdminPushRequest target) {
    return new AdminPushRequest(target.targetMode(), target.memberIds(), target.joinedOnOrBefore(),
      target.minimumAiCallCount(), "제목", "본문", "home", null);
  }

  @SuppressWarnings("unchecked")
  private static ArgumentCaptor<List<String>> listCaptor() {
    return ArgumentCaptor.forClass(List.class);
  }
}
