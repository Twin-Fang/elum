package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationDispatchSource;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository.DispatchPerformanceRow;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository.OptOutCounts;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 알림 성과 (#1275): 줄 11개(자동 9종, 운영자 직접, 예약) × 기간 2개(7일, 30일) 받은 사람·도착·열림·열림률 + 칸별 끈 사람 수
 * 도착 = 기기 1대 이상 발송 성공, 열림 = 앱이 dispatchId 로 알린 열림
 */
@Service
@Transactional(readOnly = true)
public class NotificationPerformanceService {

  public static final int SHORT_PERIOD_DAYS = 7;
  public static final int LONG_PERIOD_DAYS = 30;

  private final NotificationDispatchRepository notificationDispatchRepository;
  private final NotificationSettingRepository notificationSettingRepository;
  private final Clock clock;

  @Autowired
  public NotificationPerformanceService(NotificationDispatchRepository notificationDispatchRepository,
    NotificationSettingRepository notificationSettingRepository) {
    this(notificationDispatchRepository, notificationSettingRepository, Clock.system(NotificationTime.ZONE_ID));
  }

  NotificationPerformanceService(NotificationDispatchRepository notificationDispatchRepository,
    NotificationSettingRepository notificationSettingRepository, Clock clock) {
    this.notificationDispatchRepository = notificationDispatchRepository;
    this.notificationSettingRepository = notificationSettingRepository;
    this.clock = clock;
  }

  /// 기간 한 개의 수치: 받은 사람, 기기 도착 사람, 연 사람
  public record PeriodCounts(long recipientCount, long deliveredCount, long openedCount) {

    static final PeriodCounts EMPTY = new PeriodCounts(0, 0, 0);

    /// 열림률 % (도착 기준, 도착 0이면 null)
    public Integer openRatePercent() {
      return deliveredCount == 0 ? null : (int) Math.round(openedCount * 100.0 / deliveredCount);
    }
  }

  /// 화면 한 줄: 이름, 7일·30일 수치, 그 종류를 끈 사람 수(끌 칸이 없으면 null)
  public record PerformanceRow(String label, PeriodCounts shortPeriod, PeriodCounts longPeriod, Long optOutCount) {
  }

  public List<PerformanceRow> summarize() {
    LocalDateTime now = LocalDateTime.now(clock);
    List<DispatchPerformanceRow> shortRows = notificationDispatchRepository.summarizeSince(now.minusDays(SHORT_PERIOD_DAYS));
    List<DispatchPerformanceRow> longRows = notificationDispatchRepository.summarizeSince(now.minusDays(LONG_PERIOD_DAYS));
    OptOutCounts optOutCounts = notificationSettingRepository.countOptOuts();
    List<PerformanceRow> rows = new ArrayList<>();
    for (AutoNotificationType type : AutoNotificationType.values()) {
      rows.add(new PerformanceRow(type.getLabel(),
        countsOf(shortRows, NotificationDispatchSource.AUTO_RULE, type),
        countsOf(longRows, NotificationDispatchSource.AUTO_RULE, type), optOutCountOf(optOutCounts, type)));
    }
    for (NotificationDispatchSource source : List.of(NotificationDispatchSource.ADMIN_MANUAL,
      NotificationDispatchSource.ADMIN_SCHEDULED)) {
      rows.add(new PerformanceRow(source.getLabel(), countsOf(shortRows, source, null), countsOf(longRows, source, null),
        null));
    }
    return rows;
  }

  /// 알림 전체를 끈 사람 수
  public long countAllOff() {
    OptOutCounts optOutCounts = notificationSettingRepository.countOptOuts();
    return optOutCounts == null ? 0 : zeroIfNull(optOutCounts.getAllOffCount());
  }

  private static PeriodCounts countsOf(List<DispatchPerformanceRow> rows, NotificationDispatchSource source,
    AutoNotificationType type) {
    return rows.stream()
      .filter(row -> row.getSource() == source && Objects.equals(row.getAutoType(), type))
      .findFirst()
      .map(row -> new PeriodCounts(row.getRecipientCount(), zeroIfNull(row.getDeliveredCount()),
        zeroIfNull(row.getOpenedCount())))
      .orElse(PeriodCounts.EMPTY);
  }

  // 칸 4개 (짝은 AutoNotificationOptOut.groupOf)
  private static Long optOutCountOf(OptOutCounts counts, AutoNotificationType type) {
    if (counts == null) {
      return 0L;
    }
    return zeroIfNull(switch (AutoNotificationOptOut.groupOf(type)) {
      case ROUTINE_NUDGE -> counts.getRoutineNudgeOffCount();
      case SUGGESTION -> counts.getSuggestionOffCount();
      case PLAN_REMINDER -> counts.getPlanReminderOffCount();
      case ROUTINE_COMPLETED -> counts.getRoutineCompletedOffCount();
    });
  }

  private static long zeroIfNull(Long value) {
    return value == null ? 0 : value;
  }
}
