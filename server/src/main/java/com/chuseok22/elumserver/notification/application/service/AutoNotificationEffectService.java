package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.member.application.service.MemberEngagementQueryService;
import com.chuseok22.elumserver.member.application.service.MemberEngagementQueryService.ReturnEvidence;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationDispatchSource;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository.DispatchOutcomeRow;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 자동 알림 규칙별 효과 (#1409, passQL 규칙별 발송·열람·복귀 표와 같은 모양): 최근 7일 보냄·열림·24시간 안 복귀
 * 복귀 3가지 중 하나: 24시간 안 알림 열림, 마지막 활동 시각이 24시간 안, 보낸 다음 날 방문 기록 (방문은 날짜 단위라 근사)
 */
@Service
@Transactional(readOnly = true)
public class AutoNotificationEffectService {

  public static final int EFFECT_PERIOD_DAYS = 7;
  public static final int RETURN_WINDOW_HOURS = 24;

  private final NotificationDispatchRepository notificationDispatchRepository;
  private final MemberEngagementQueryService memberEngagementQueryService;
  private final Clock clock;

  @Autowired
  public AutoNotificationEffectService(NotificationDispatchRepository notificationDispatchRepository,
    MemberEngagementQueryService memberEngagementQueryService) {
    this(notificationDispatchRepository, memberEngagementQueryService, Clock.system(NotificationTime.ZONE_ID));
  }

  AutoNotificationEffectService(NotificationDispatchRepository notificationDispatchRepository,
    MemberEngagementQueryService memberEngagementQueryService, Clock clock) {
    this.notificationDispatchRepository = notificationDispatchRepository;
    this.memberEngagementQueryService = memberEngagementQueryService;
    this.clock = clock;
  }

  /// 화면 한 줄: 규칙 이름, 보낸 사람 수(발송 기록 수), 연 수, 24시간 안 복귀 수
  public record EffectRow(String label, long sentCount, long openedCount, long returnedCount) {

    /// 열림률 % (보냄 0이면 null)
    public Integer openRatePercent() {
      return percentOf(openedCount, sentCount);
    }

    /// 복귀율 % (보냄 0이면 null)
    public Integer returnRatePercent() {
      return percentOf(returnedCount, sentCount);
    }

    private static Integer percentOf(long count, long total) {
      return total == 0 ? null : (int) Math.round(count * 100.0 / total);
    }
  }

  /// 최근 7일 자동 발송 > 규칙별 보냄·열림·복귀 (종류 순서, 안 보낸 규칙도 0 줄)
  public List<EffectRow> summarizeRecent() {
    LocalDateTime since = LocalDateTime.now(clock).minusDays(EFFECT_PERIOD_DAYS);
    List<DispatchOutcomeRow> outcomes =
      notificationDispatchRepository.findOutcomesBySourceSince(NotificationDispatchSource.AUTO_RULE, since);
    Map<String, ReturnEvidence> evidenceByMemberId = memberEngagementQueryService.returnEvidenceOf(
      outcomes.stream().map(DispatchOutcomeRow::getMemberId).toList(), since.toLocalDate());
    List<EffectRow> rows = new ArrayList<>();
    for (AutoNotificationType type : AutoNotificationType.values()) {
      long sentCount = 0;
      long openedCount = 0;
      long returnedCount = 0;
      for (DispatchOutcomeRow outcome : outcomes) {
        if (outcome.getAutoType() != type) {
          continue;
        }
        sentCount++;
        openedCount += outcome.getOpenedAt() == null ? 0 : 1;
        returnedCount += isReturnedWithinWindow(outcome.getSentAt(), outcome.getOpenedAt(),
          evidenceByMemberId.get(outcome.getMemberId())) ? 1 : 0;
      }
      rows.add(new EffectRow(type.getLabel(), sentCount, openedCount, returnedCount));
    }
    return rows;
  }

  /// 보낸 뒤 24시간 안 복귀: 열림 > 마지막 활동 > 다음 날 방문 차례로 확인
  static boolean isReturnedWithinWindow(LocalDateTime sentAt, LocalDateTime openedAt, ReturnEvidence evidence) {
    if (sentAt == null) {
      return false;
    }
    LocalDateTime deadline = sentAt.plusHours(RETURN_WINDOW_HOURS);
    if (isWithin(openedAt, sentAt, deadline)) {
      return true;
    }
    if (evidence == null) {
      return false;
    }
    if (isWithin(evidence.lastActivityAt(), sentAt, deadline)) {
      return true;
    }
    Set<LocalDate> visitDates = evidence.visitDates() == null ? Set.of() : evidence.visitDates();
    return visitDates.contains(sentAt.toLocalDate().plusDays(1));
  }

  // [start, end] 안인지 (null 이면 아님)
  private static boolean isWithin(LocalDateTime time, LocalDateTime start, LocalDateTime end) {
    return time != null && !time.isBefore(start) && !time.isAfter(end);
  }
}
