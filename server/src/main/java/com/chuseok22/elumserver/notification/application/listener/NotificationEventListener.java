package com.chuseok22.elumserver.notification.application.listener;

import com.chuseok22.elumserver.common.infrastructure.config.AsyncConfig;
import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.notification.application.service.NotificationRecorder;
import com.chuseok22.elumserver.notification.application.service.RecordedNotification;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.core.event.CoGuardianJoinedEvent;
import com.chuseok22.elumserver.notification.core.event.FeedbackResolvedEvent;
import com.chuseok22.elumserver.notification.core.event.RoutineCompletedEvent;
import com.chuseok22.elumserver.notification.core.event.RoutineSentEvent;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Collection;
import java.util.List;
import java.util.function.Supplier;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 알림 이벤트 수신: 일과 완료, 일과 보냄, 공동 보호자 합류, 의견 처리
 * 커밋 뒤 + 별도 스레드 > 받는 사람 계산(요청자 제외) > 기록 (실패는 로그만, 본래 요청에 영향 없음)
 */
@Slf4j
@Component
public class NotificationEventListener {

  private static final ZoneId NOTIFICATION_ZONE = ZoneId.of("Asia/Seoul");

  private final NotificationRecorder notificationRecorder;
  private final ProfileGuardianService profileGuardianService;
  private final Clock clock;

  @Autowired
  public NotificationEventListener(NotificationRecorder notificationRecorder,
    ProfileGuardianService profileGuardianService) {
    this(notificationRecorder, profileGuardianService, Clock.system(NOTIFICATION_ZONE));
  }

  NotificationEventListener(NotificationRecorder notificationRecorder, ProfileGuardianService profileGuardianService,
    Clock clock) {
    this.notificationRecorder = notificationRecorder;
    this.profileGuardianService = profileGuardianService;
    this.clock = clock;
  }

  @Async(AsyncConfig.NOTIFICATION_EXECUTOR)
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void onRoutineCompleted(RoutineCompletedEvent event) {
    recordSafely(NotificationType.ROUTINE_COMPLETED.name(), () -> {
      NotificationDraft draft = NotificationDraft.routineCompleted(event.profileId(), event.routineId(),
        event.routineDate(), now());
      // 받는 사람: 이룸이의 보호자 전원 - 요청한 보호자 (이룸이 기기가 완료했으면 연결해 준 보호자도 포함)
      return notificationRecorder.record(draft, guardiansExcept(event.profileId(), event.actorMemberId()));
    });
  }

  @Async(AsyncConfig.NOTIFICATION_EXECUTOR)
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void onRoutineSent(RoutineSentEvent event) {
    recordSafely(NotificationType.ROUTINE_SENT_BY_CO_GUARDIAN.name(), () -> {
      NotificationDraft draft = NotificationDraft.routineSent(event.profileId(), event.routineId(), now());
      return notificationRecorder.record(draft, guardiansExcept(event.profileId(), event.actorMemberId()));
    });
  }

  @Async(AsyncConfig.NOTIFICATION_EXECUTOR)
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void onCoGuardianJoined(CoGuardianJoinedEvent event) {
    recordSafely(NotificationType.CO_GUARDIAN_JOINED.name(), () -> {
      NotificationDraft draft = NotificationDraft.coGuardianJoined(event.profileId(), event.joinedMemberId(), now());
      // 받는 사람: 기존 보호자 전원 (합류한 본인 제외)
      return notificationRecorder.record(draft, guardiansExcept(event.profileId(), event.joinedMemberId()));
    });
  }

  @Async(AsyncConfig.NOTIFICATION_EXECUTOR)
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void onFeedbackResolved(FeedbackResolvedEvent event) {
    recordSafely(NotificationType.FEEDBACK_RESOLVED.name(), () -> {
      NotificationDraft draft = NotificationDraft.feedbackResolved(event.feedbackId(), now());
      // 받는 사람: 의견을 보낸 사람 한 명
      return notificationRecorder.record(draft, List.of(event.memberId()));
    });
  }

  /// 기록 실행 > 완료 로그 (예외는 로그만 남기고 삼킴: 본래 요청과 무관하게 끝남)
  private void recordSafely(String typeName, Supplier<List<RecordedNotification>> recording) {
    try {
      List<RecordedNotification> recorded = recording.get();
      log.info("[notification record] done type={} count={}", typeName, recorded.size());
    } catch (RuntimeException exception) {
      log.warn("[notification record] failed type={} : {}", typeName, exception.getClass().getSimpleName());
    }
  }

  private Collection<String> guardiansExcept(String profileId, String excludedMemberId) {
    return profileGuardianService.guardianMemberIdsOf(profileId).stream()
      .filter(memberId -> !memberId.equals(excludedMemberId))
      .toList();
  }

  private LocalDateTime now() {
    return LocalDateTime.now(clock);
  }
}
