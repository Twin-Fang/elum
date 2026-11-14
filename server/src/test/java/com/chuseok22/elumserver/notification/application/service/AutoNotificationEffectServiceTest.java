package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.application.service.MemberEngagementQueryService;
import com.chuseok22.elumserver.member.application.service.MemberEngagementQueryService.ReturnEvidence;
import com.chuseok22.elumserver.notification.application.service.AutoNotificationEffectService.EffectRow;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationDispatchSource;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository.DispatchOutcomeRow;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 규칙별 효과 표가 틀리면 운영자가 잘못 고르는 규칙을 못 끄거나 잘 되는 규칙을 끈다 (#1409, 설계 6. 실패 경로)
class AutoNotificationEffectServiceTest {

  private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");
  private static final LocalDateTime SENT_AT = LocalDateTime.of(2026, 11, 10, 10, 0);

  @Test
  @DisplayName("24시간 안에 열었으면 복귀")
  void openedWithinDay_isReturned() {
    assertThat(AutoNotificationEffectService.isReturnedWithinWindow(SENT_AT, SENT_AT.plusHours(3), null)).isTrue();
  }

  @Test
  @DisplayName("열지 않았어도 마지막 활동이 24시간 안이면 복귀, 보내기 전 활동은 아님")
  void lastActivityWithinDay_isReturned() {
    ReturnEvidence within = new ReturnEvidence(SENT_AT.plusHours(20), Set.of());
    ReturnEvidence before = new ReturnEvidence(SENT_AT.minusMinutes(5), Set.of());

    assertThat(AutoNotificationEffectService.isReturnedWithinWindow(SENT_AT, null, within)).isTrue();
    assertThat(AutoNotificationEffectService.isReturnedWithinWindow(SENT_AT, null, before)).isFalse();
  }

  @Test
  @DisplayName("마지막 활동이 그 뒤로 덮였어도 보낸 다음 날 방문 기록이 있으면 복귀, 그다음 날 방문은 아님")
  void nextDayVisit_isReturned_laterVisitIsNot() {
    LocalDate nextDay = SENT_AT.toLocalDate().plusDays(1);
    ReturnEvidence nextDayVisit = new ReturnEvidence(SENT_AT.plusDays(4), Set.of(nextDay));
    ReturnEvidence laterVisit = new ReturnEvidence(SENT_AT.plusDays(4), Set.of(nextDay.plusDays(1)));

    assertThat(AutoNotificationEffectService.isReturnedWithinWindow(SENT_AT, null, nextDayVisit)).isTrue();
    assertThat(AutoNotificationEffectService.isReturnedWithinWindow(SENT_AT, null, laterVisit)).isFalse();
  }

  @Test
  @DisplayName("규칙마다 보냄·열림·복귀를 세고, 안 보낸 규칙도 0 줄로 나온다")
  void summarizeRecent_countsPerRule() {
    NotificationDispatchRepository dispatchRepository = mock(NotificationDispatchRepository.class);
    MemberEngagementQueryService memberQuery = mock(MemberEngagementQueryService.class);
    Clock clock = Clock.fixed(LocalDateTime.of(2026, 11, 14, 12, 0).atZone(SEOUL).toInstant(), SEOUL);
    when(dispatchRepository.findOutcomesBySourceSince(eq(NotificationDispatchSource.AUTO_RULE), any())).thenReturn(List.of(
      outcome("m-opened", AutoNotificationType.STREAK_AT_RISK, SENT_AT.plusHours(1)),
      outcome("m-came-back", AutoNotificationType.STREAK_AT_RISK, null),
      outcome("m-gone", AutoNotificationType.STREAK_AT_RISK, null)));
    when(memberQuery.returnEvidenceOf(anyCollection(), any())).thenReturn(Map.of(
      "m-opened", new ReturnEvidence(null, Set.of()),
      "m-came-back", new ReturnEvidence(SENT_AT.plusHours(5), Set.of()),
      "m-gone", new ReturnEvidence(SENT_AT.minusDays(2), Set.of())));

    List<EffectRow> rows = new AutoNotificationEffectService(dispatchRepository, memberQuery, clock).summarizeRecent();

    assertThat(rows).hasSize(AutoNotificationType.values().length);
    assertThat(rows).filteredOn(row -> row.label().equals(AutoNotificationType.STREAK_AT_RISK.getLabel()))
      .singleElement()
      .satisfies(row -> {
        assertThat(row.sentCount()).isEqualTo(3);
        assertThat(row.openedCount()).isEqualTo(1);
        assertThat(row.returnedCount()).isEqualTo(2);
        assertThat(row.returnRatePercent()).isEqualTo(67);
      });
    assertThat(rows).filteredOn(row -> row.label().equals(AutoNotificationType.LINK_PENDING.getLabel()))
      .singleElement()
      .satisfies(row -> assertThat(row.openRatePercent()).isNull());
  }

  private static DispatchOutcomeRow outcome(String memberId, AutoNotificationType type, LocalDateTime openedAt) {
    return new DispatchOutcomeRow() {
      @Override
      public String getMemberId() {
        return memberId;
      }

      @Override
      public AutoNotificationType getAutoType() {
        return type;
      }

      @Override
      public LocalDateTime getSentAt() {
        return SENT_AT;
      }

      @Override
      public LocalDateTime getOpenedAt() {
        return openedAt;
      }
    };
  }
}
