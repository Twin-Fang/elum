package com.chuseok22.elumserver.notification.application.service;

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

import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationDispatchSource;
import com.chuseok22.elumserver.notification.infrastructure.entity.AutoNotificationRule;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.repository.AutoNotificationRuleRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 자동 알림이 밤에 가거나, 하루 2개 가거나, 끈 사람·간격 안 사람에게 가면 보호자가 알림을 끄고 떠난다 (#1275)
class AutoNotificationRunnerTest {

  private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

  private final AutoNotificationRuleRepository ruleRepository = mock(AutoNotificationRuleRepository.class);
  private final AutoNotificationCandidateFinder candidateFinder = mock(AutoNotificationCandidateFinder.class);
  private final NotificationSettingRepository settingRepository = mock(NotificationSettingRepository.class);
  private final NotificationDispatchRepository dispatchRepository = mock(NotificationDispatchRepository.class);
  private final AdminMessageService adminMessageService = mock(AdminMessageService.class);

  private AutoNotificationRunner runnerAt(String seoulDateTime) {
    LocalDateTime local = LocalDateTime.parse(seoulDateTime);
    Clock clock = Clock.fixed(local.atZone(SEOUL).toInstant(), SEOUL);
    return new AutoNotificationRunner(ruleRepository, candidateFinder, settingRepository, dispatchRepository,
      adminMessageService, clock);
  }

  @Test
  @DisplayName("야간(21시~08시 전)에는 규칙을 읽지도 보내지도 않는다")
  void runOnce_quietHours_sendsNothing() {
    assertThat(runnerAt("2026-11-12T21:00").runOnce()).isZero();
    assertThat(runnerAt("2026-11-12T07:59").runOnce()).isZero();

    verifyNoInteractions(ruleRepository, candidateFinder, adminMessageService);
  }

  @Test
  @DisplayName("정한 시각 전이면 선점하지 않고, 다른 인스턴스가 오늘 이미 선점했으면 받을 사람을 찾지 않는다")
  void runOnce_beforeSendTimeOrAlreadyClaimed_doesNotSend() {
    when(ruleRepository.findAllEnabled()).thenReturn(List.of(rule(AutoNotificationType.COMEBACK, 10, 0, 7)));

    runnerAt("2026-11-12T09:59").runOnce();
    verify(ruleRepository, never()).claimTodayRun(any(), any());

    when(ruleRepository.claimTodayRun(AutoNotificationType.COMEBACK, LocalDate.of(2026, 11, 12))).thenReturn(0);
    runnerAt("2026-11-12T10:10").runOnce();
    verify(candidateFinder, never()).find(any(), any());
    verify(adminMessageService, never()).send(anyString(), anyString(), any(), anyCollection(), any());
  }

  @Test
  @DisplayName("끈 사람·간격 안 사람·오늘 이미 자동 알림 받은 사람은 빼고, 남은 사람에게 문구를 채워 자동 출처로 보낸다")
  void runOnce_filtersOptOutIntervalAndDailyCap_thenSendsRendered() {
    AutoNotificationRule nudge = rule(AutoNotificationType.DAILY_ROUTINE_NUDGE, 8, 0, 1);
    when(ruleRepository.findAllEnabled()).thenReturn(List.of(nudge));
    when(ruleRepository.claimTodayRun(eq(AutoNotificationType.DAILY_ROUTINE_NUDGE), any())).thenReturn(1);
    when(candidateFinder.find(eq(AutoNotificationType.DAILY_ROUTINE_NUDGE), any())).thenReturn(List.of(
      new AutoNotificationCandidate("m-ok", "하늘이", "아침 준비", null),
      new AutoNotificationCandidate("m-nudge-off", "바다", "양치", null),
      new AutoNotificationCandidate("m-all-off", "별이", "양치", null),
      new AutoNotificationCandidate("m-interval", "숲이", "양치", null),
      new AutoNotificationCandidate("m-capped", "해", "양치", null)));
    NotificationSetting nudgeOff = setting("m-nudge-off");
    nudgeOff.setRoutineNudgeEnabled(false);
    NotificationSetting allOff = setting("m-all-off");
    allOff.setAllEnabled(false);
    when(settingRepository.findAllById(anyCollection())).thenReturn(List.of(nudgeOff, allOff));
    when(dispatchRepository.findMemberIdsWithAutoTypeSince(eq(AutoNotificationType.DAILY_ROUTINE_NUDGE), anyCollection(),
      any())).thenReturn(List.of("m-interval"));
    when(dispatchRepository.findMemberIdsWithSourceSince(eq(NotificationDispatchSource.AUTO_RULE), anyCollection(),
      eq(LocalDateTime.parse("2026-11-12T00:00")))).thenReturn(List.of("m-capped"));

    int sentCount = runnerAt("2026-11-12T08:05").runOnce();

    assertThat(sentCount).isEqualTo(1);
    verify(adminMessageService).send("🌤️ 오늘 아침 준비도 하늘이에게 보내 줄까요?", "눌러서 보내 보세요",
      AdminMessageRoute.HOME, List.of("m-ok"), AdminMessageOrigin.autoRule(AutoNotificationType.DAILY_ROUTINE_NUDGE));
  }

  @Test
  @DisplayName("최소 간격은 오늘 포함 일수로 센다 (7일이면 6일 전 0시부터), 첫 일과 축하는 평생 한 번")
  void intervalStartOf_countsTodayAndFirstRoutineIsOnceEver() {
    LocalDateTime now = LocalDateTime.parse("2026-11-12T10:00");

    assertThat(AutoNotificationRunner.intervalStartOf(rule(AutoNotificationType.COMEBACK, 10, 0, 7), now))
      .isEqualTo(LocalDateTime.parse("2026-11-06T00:00"));
    assertThat(AutoNotificationRunner.intervalStartOf(rule(AutoNotificationType.DAILY_ROUTINE_NUDGE, 8, 0, 1), now))
      .isEqualTo(LocalDateTime.parse("2026-11-12T00:00"));
    assertThat(AutoNotificationRunner.intervalStartOf(rule(AutoNotificationType.FIRST_ROUTINE_DONE, 8, 0, 1), now))
      .isBefore(LocalDateTime.parse("2001-01-01T00:00"));
  }

  private static AutoNotificationRule rule(AutoNotificationType type, int hour, int minute, int intervalDays) {
    AutoNotificationRule rule = new AutoNotificationRule();
    rule.setType(type);
    rule.setEnabled(true);
    rule.setTitleTemplate("🌤️ 오늘 {일과}도 {아이이름}에게 보내 줄까요?");
    rule.setBodyTemplate("눌러서 보내 보세요");
    rule.setRoute(AdminMessageRoute.HOME);
    rule.setSendHour(hour);
    rule.setSendMinute(minute);
    rule.setMinIntervalDays(intervalDays);
    return rule;
  }

  private static NotificationSetting setting(String memberId) {
    NotificationSetting setting = new NotificationSetting();
    setting.setMemberId(memberId);
    return setting;
  }
}
