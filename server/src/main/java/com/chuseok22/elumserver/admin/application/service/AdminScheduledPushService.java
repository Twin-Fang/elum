package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.request.AdminPushRequest;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushSendResponse;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminPushOutcome;
import com.chuseok22.elumserver.notification.application.service.ScheduledAdminPushStore;
import com.chuseok22.elumserver.notification.application.service.ScheduledAdminPushStore.ScheduledAdminPushResult;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.NotificationQuietHours;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.infrastructure.entity.ScheduledAdminPush;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 예약 발송 (#1275): 만들기(시각·내용·받는 사람 검사 > 저장 > 관리자 기록), 취소, 보낼 차례 보내기(선점 > #1273 보내기 > 결과)
 * 시각 검사 2개: 지난 시각 금지, 야간(21~08시) 금지. 받는 사람은 보낼 때 다시 계산
 */
@Slf4j
@Service
public class AdminScheduledPushService {

  // 보낼 시각이 이보다 오래 지난 예약은 보내지 않고 실패 처리 (서버가 오래 멈췄다 켜진 경우)
  static final int STALE_AFTER_HOURS = 6;
  static final String STALE_FAILURE_REASON = "STALE";
  static final String ERROR_FAILURE_REASON = "ERROR";
  private static final String MEMBER_ID_DELIMITER = ",";

  private final AdminPushService adminPushService;
  private final ScheduledAdminPushStore scheduledAdminPushStore;
  private final AdminAuditService adminAuditService;
  private final Clock clock;

  @Autowired
  public AdminScheduledPushService(AdminPushService adminPushService, ScheduledAdminPushStore scheduledAdminPushStore,
    AdminAuditService adminAuditService) {
    this(adminPushService, scheduledAdminPushStore, adminAuditService, Clock.system(NotificationTime.ZONE_ID));
  }

  AdminScheduledPushService(AdminPushService adminPushService, ScheduledAdminPushStore scheduledAdminPushStore,
    AdminAuditService adminAuditService, Clock clock) {
    this.adminPushService = adminPushService;
    this.scheduledAdminPushStore = scheduledAdminPushStore;
    this.adminAuditService = adminAuditService;
    this.clock = clock;
  }

  /// 만들기 결과: 저장했으면 예약 id, 거절이면 사유 문구
  public record ScheduleResult(boolean isCreated, String scheduledPushId, String rejectionMessage) {

    static ScheduleResult rejected(String rejectionMessage) {
      return new ScheduleResult(false, null, rejectionMessage);
    }
  }

  /// 만들기: 시각 > 내용·받는 사람·인원 > 저장 > 관리자 기록
  public ScheduleResult create(AdminPushRequest request, String scheduledAtText, String adminUsername) {
    Optional<LocalDateTime> scheduledAt = parseDateTime(scheduledAtText);
    if (scheduledAt.isEmpty()) {
      return ScheduleResult.rejected("보낼 날짜·시각을 골라 주세요");
    }
    if (!scheduledAt.get().isAfter(LocalDateTime.now(clock))) {
      return ScheduleResult.rejected("지난 시각에는 예약할 수 없어요");
    }
    if (NotificationQuietHours.isQuietTime(scheduledAt.get())) {
      return ScheduleResult.rejected("밤 9시부터 아침 8시까지는 예약할 수 없어요");
    }
    Optional<AdminPushOutcome> rejection = adminPushService.rejectionForSchedule(request);
    if (rejection.isPresent()) {
      return ScheduleResult.rejected(rejection.get().getMessage() + " (" + rejection.get().getErrorCode() + ")");
    }
    ScheduledAdminPush saved = scheduledAdminPushStore.create(toScheduledPush(request, scheduledAt.get(), adminUsername));
    adminAuditService.record(AdminAuditAction.SCHEDULED_PUSH_CREATED, saved.getId(),
      "보낼 시각 " + saved.getScheduledAt() + " · 방식 " + saved.getTargetMode());
    return new ScheduleResult(true, saved.getId(), null);
  }

  /// 취소: 기다림일 때만 > 관리자 기록
  public boolean cancel(String scheduledPushId) {
    boolean isCanceled = scheduledAdminPushStore.cancel(scheduledPushId);
    if (isCanceled) {
      adminAuditService.record(AdminAuditAction.SCHEDULED_PUSH_CANCELED, scheduledPushId, "예약 취소");
    }
    return isCanceled;
  }

  public List<ScheduledAdminPush> findRecent() {
    return scheduledAdminPushStore.findRecent();
  }

  /// 보낼 차례 보내기: 야간이면 멈춤 > 지난 예약마다 선점 > 오래 지났으면 실패 > 보내기 > 결과 (보낸 예약 수)
  public int sendDue() {
    LocalDateTime now = LocalDateTime.now(clock);
    if (NotificationQuietHours.isQuietTime(now)) {
      return 0;
    }
    int sentCount = 0;
    for (String scheduledPushId : scheduledAdminPushStore.findDueIds(now)) {
      if (!scheduledAdminPushStore.claim(scheduledPushId)) {
        continue;
      }
      if (sendClaimed(scheduledPushId, now)) {
        sentCount++;
      }
    }
    return sentCount;
  }

  // 선점한 예약 한 건 보내기 (실패도 결과로 남김: 보내는 중에 멈춰 있지 않게)
  private boolean sendClaimed(String scheduledPushId, LocalDateTime now) {
    try {
      Optional<ScheduledAdminPush> scheduled = scheduledAdminPushStore.findById(scheduledPushId);
      if (scheduled.isEmpty()) {
        return false;
      }
      if (scheduled.get().getScheduledAt().isBefore(now.minusHours(STALE_AFTER_HOURS))) {
        scheduledAdminPushStore.finish(scheduledPushId, ScheduledAdminPushResult.failed(STALE_FAILURE_REASON));
        return false;
      }
      AdminPushSendResponse response = adminPushService.sendScheduled(toRequest(scheduled.get()));
      boolean isSent = AdminPushOutcome.SENT.name().equals(response.outcome());
      scheduledAdminPushStore.finish(scheduledPushId, new ScheduledAdminPushResult(isSent, response.messageId(),
        response.recipientCount(), response.recordedMemberCount(), response.sentDeviceCount(),
        response.failedDeviceCount(), isSent ? null : response.outcome()));
      log.info("[scheduled push] processed : id={}, outcome={}, recipients={}", scheduledPushId, response.outcome(),
        response.recipientCount());
      return isSent;
    } catch (RuntimeException exception) {
      log.warn("[scheduled push] failed : id={}, {}", scheduledPushId, exception.getClass().getSimpleName());
      scheduledAdminPushStore.finish(scheduledPushId, ScheduledAdminPushResult.failed(ERROR_FAILURE_REASON));
      return false;
    }
  }

  // 요청 > 저장할 예약 (문구는 다듬어 저장, 받는 사람 조건은 그대로)
  private static ScheduledAdminPush toScheduledPush(AdminPushRequest request, LocalDateTime scheduledAt,
    String adminUsername) {
    ScheduledAdminPush scheduled = new ScheduledAdminPush();
    scheduled.setTitle(request.title().strip());
    scheduled.setBody(request.body().strip());
    scheduled.setRoute(AdminMessageRoute.fromWire(request.route()).orElseThrow());
    scheduled.setTargetMode(request.targetMode());
    scheduled.setMemberIds(request.memberIds() == null ? null : String.join(MEMBER_ID_DELIMITER, request.memberIds()));
    scheduled.setJoinedOnOrBefore(parseDate(request.joinedOnOrBefore()));
    scheduled.setMinimumAiCallCount(request.minimumAiCallCount());
    scheduled.setScheduledAt(scheduledAt);
    scheduled.setCreatedBy(adminUsername);
    return scheduled;
  }

  // 저장한 예약 > #1273 보내기 요청 (먼저 보내 보기 회원 없음)
  static AdminPushRequest toRequest(ScheduledAdminPush scheduled) {
    List<String> memberIds = scheduled.getMemberIds() == null || scheduled.getMemberIds().isBlank()
      ? List.of() : Arrays.stream(scheduled.getMemberIds().split(MEMBER_ID_DELIMITER)).map(String::strip).toList();
    return new AdminPushRequest(scheduled.getTargetMode(), memberIds,
      scheduled.getJoinedOnOrBefore() == null ? null : scheduled.getJoinedOnOrBefore().toString(),
      scheduled.getMinimumAiCallCount(), scheduled.getTitle(), scheduled.getBody(),
      scheduled.getRoute().getWire(), null);
  }

  // "2026-11-20" > 날짜 (비었거나 틀리면 null: 고른 회원 방식은 쓰지 않는 값)
  private static LocalDate parseDate(String text) {
    if (text == null || text.isBlank()) {
      return null;
    }
    try {
      return LocalDate.parse(text.strip());
    } catch (DateTimeParseException exception) {
      return null;
    }
  }

  // "2026-11-20T10:30" (datetime-local) > 시각
  private static Optional<LocalDateTime> parseDateTime(String text) {
    if (text == null || text.isBlank()) {
      return Optional.empty();
    }
    try {
      return Optional.of(LocalDateTime.parse(text.strip()));
    } catch (DateTimeParseException exception) {
      return Optional.empty();
    }
  }
}
