package com.chuseok22.elumserver.notification.infrastructure.scheduler;

import com.chuseok22.elumserver.credit.application.service.CreditQueryService;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.notification.application.service.NotificationRecorder;
import com.chuseok22.elumserver.notification.application.service.PushDispatcher;
import com.chuseok22.elumserver.notification.application.service.RecordedNotification;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationType;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 크레딧 다시 채움 알림: 지난 주기에 다 쓴 보호자 조회 > 이번 주기 키로 기록 > 푸시
 * 같은 묶음 키라 재실행해도 중복 기록·재푸시 없음 (인스턴스가 둘이어도 안전)
 */
@Slf4j
@Component
public class CreditRefillNotificationScheduler {

  private static final ZoneId NOTIFICATION_ZONE = ZoneId.of("Asia/Seoul");
  // 한 번에 기록할 보호자 수 (목록 전체를 한꺼번에 쥐지 않음)
  private static final int RECIPIENT_CHUNK_SIZE = 200;

  private final CreditQueryService creditQueryService;
  private final NotificationRecorder notificationRecorder;
  private final PushDispatcher pushDispatcher;
  private final Clock clock;

  @Autowired
  public CreditRefillNotificationScheduler(CreditQueryService creditQueryService,
    NotificationRecorder notificationRecorder, PushDispatcher pushDispatcher) {
    this(creditQueryService, notificationRecorder, pushDispatcher, Clock.system(NOTIFICATION_ZONE));
  }

  CreditRefillNotificationScheduler(CreditQueryService creditQueryService, NotificationRecorder notificationRecorder,
    PushDispatcher pushDispatcher, Clock clock) {
    this.creditQueryService = creditQueryService;
    this.notificationRecorder = notificationRecorder;
    this.pushDispatcher = pushDispatcher;
    this.clock = clock;
  }

  // 월요일 오전 9시(한국 시각): 새 주기 지급이 이미 시작된 뒤
  @Scheduled(cron = "${elum.notification.credit-refill-cron:0 0 9 * * MON}", zone = "Asia/Seoul")
  public void run() {
    try {
      notifyDepletedMembers();
    } catch (RuntimeException exception) {
      // 스케줄러 밖으로 던지지 않음
      log.warn("[notification record] failed type={} : {}", NotificationType.CREDIT_REFILLED,
        exception.getClass().getSimpleName());
    }
  }

  private void notifyDepletedMembers() {
    LocalDateTime now = LocalDateTime.now(clock);
    CreditPeriod previousPeriod = CreditPeriod.of(now.minusWeeks(1));
    String thisPeriodKey = CreditPeriod.of(now).key();

    List<String> memberIds = creditQueryService.memberIdsDepletedIn(previousPeriod);
    if (memberIds.isEmpty()) {
      return;
    }
    NotificationDraft draft = NotificationDraft.creditRefilled(thisPeriodKey, now);
    // 묶음 단위 기록 + 발송
    for (int from = 0; from < memberIds.size(); from += RECIPIENT_CHUNK_SIZE) {
      List<String> chunk = memberIds.subList(from, Math.min(from + RECIPIENT_CHUNK_SIZE, memberIds.size()));
      List<RecordedNotification> recorded = notificationRecorder.record(draft, chunk);
      pushDispatcher.dispatch(recorded, NotificationType.CREDIT_REFILLED);
    }
  }
}
