package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.request.AdminPushRequest;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushSendResponse;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.notification.application.service.AdminMessageSendResult;
import com.chuseok22.elumserver.notification.application.service.ScheduledAdminPushStore;
import com.chuseok22.elumserver.notification.application.service.ScheduledAdminPushStore.ScheduledAdminPushResult;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.infrastructure.entity.ScheduledAdminPush;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/// 예약이 밤·지난 시각에 잡히거나, 두 번 가거나, 취소했는데 가면 운영자 신뢰가 깨진다 (#1275)
class AdminScheduledPushServiceTest {

  private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

  private final AdminPushService adminPushService = mock(AdminPushService.class);
  private final ScheduledAdminPushStore store = mock(ScheduledAdminPushStore.class);
  private final AdminAuditService adminAuditService = mock(AdminAuditService.class);

  private AdminScheduledPushService serviceAt(String seoulDateTime) {
    Clock clock = Clock.fixed(LocalDateTime.parse(seoulDateTime).atZone(SEOUL).toInstant(), SEOUL);
    return new AdminScheduledPushService(adminPushService, store, adminAuditService, clock);
  }

  @Test
  @DisplayName("야간 시각·지난 시각 예약은 저장하지 않고 사유를 돌려준다")
  void create_quietHoursOrPast_rejectedWithoutSaving() {
    AdminScheduledPushService service = serviceAt("2026-11-12T10:00");

    assertThat(service.create(request(), "2026-11-12T21:30", "admin").isCreated()).isFalse();
    assertThat(service.create(request(), "2026-11-13T07:59", "admin").isCreated()).isFalse();
    assertThat(service.create(request(), "2026-11-12T09:00", "admin").isCreated()).isFalse();

    verify(store, never()).create(any());
    verifyNoInteractions(adminAuditService);
  }

  @Test
  @DisplayName("낮 시각 예약은 저장하고 관리자 기록을 남긴다")
  void create_daytime_savedAndAudited() {
    when(adminPushService.rejectionForSchedule(any())).thenReturn(Optional.empty());
    when(store.create(any())).thenAnswer(invocation -> {
      ScheduledAdminPush saved = invocation.getArgument(0);
      saved.setId("s1");
      return saved;
    });

    assertThat(serviceAt("2026-11-12T10:00").create(request(), "2026-11-13T09:30", "admin").isCreated()).isTrue();

    ArgumentCaptor<ScheduledAdminPush> saved = ArgumentCaptor.forClass(ScheduledAdminPush.class);
    verify(store).create(saved.capture());
    assertThat(saved.getValue().getScheduledAt()).isEqualTo(LocalDateTime.parse("2026-11-13T09:30"));
    assertThat(saved.getValue().getMemberIds()).isEqualTo("m1,m2");
    verify(adminAuditService).record(eq(AdminAuditAction.SCHEDULED_PUSH_CREATED), eq("s1"), anyString());
  }

  @Test
  @DisplayName("보낼 차례: 선점한 예약만 한 번 보내고(취소·다른 인스턴스가 선점한 것은 안 보냄) 보냄으로 남긴다")
  void sendDue_sendsOnlyClaimedOnce() {
    when(store.findDueIds(any())).thenReturn(List.of("s-claimed", "s-canceled"));
    when(store.claim("s-claimed")).thenReturn(true);
    when(store.claim("s-canceled")).thenReturn(false);
    when(store.findById("s-claimed")).thenReturn(Optional.of(scheduled("2026-11-12T10:00")));
    when(adminPushService.sendScheduled(any())).thenReturn(
      AdminPushSendResponse.sent(2, new AdminMessageSendResult("msg-1", 2, 3, 0)));

    int sentCount = serviceAt("2026-11-12T10:01").sendDue();

    assertThat(sentCount).isEqualTo(1);
    verify(adminPushService, times(1)).sendScheduled(any());
    ArgumentCaptor<ScheduledAdminPushResult> result = ArgumentCaptor.forClass(ScheduledAdminPushResult.class);
    verify(store).finish(eq("s-claimed"), result.capture());
    assertThat(result.getValue().isSent()).isTrue();
    assertThat(result.getValue().adminMessageId()).isEqualTo("msg-1");
    verify(store, never()).finish(eq("s-canceled"), any());
  }

  @Test
  @DisplayName("야간에는 보낼 차례를 찾지 않는다")
  void sendDue_quietHours_nothing() {
    assertThat(serviceAt("2026-11-12T22:00").sendDue()).isZero();

    verifyNoInteractions(store, adminPushService);
  }

  private static AdminPushRequest request() {
    return new AdminPushRequest("MEMBERS", List.of("m1", "m2"), null, null, "제목", "본문", "home", null);
  }

  private static ScheduledAdminPush scheduled(String scheduledAt) {
    ScheduledAdminPush scheduled = new ScheduledAdminPush();
    scheduled.setId("s-claimed");
    scheduled.setTitle("제목");
    scheduled.setBody("본문");
    scheduled.setRoute(AdminMessageRoute.HOME);
    scheduled.setTargetMode("MEMBERS");
    scheduled.setMemberIds("m1,m2");
    scheduled.setScheduledAt(LocalDateTime.parse(scheduledAt));
    return scheduled;
  }
}
