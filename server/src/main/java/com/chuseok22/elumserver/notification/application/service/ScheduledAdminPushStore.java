package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.core.ScheduledAdminPushStatus;
import com.chuseok22.elumserver.notification.infrastructure.entity.ScheduledAdminPush;
import com.chuseok22.elumserver.notification.infrastructure.repository.ScheduledAdminPushRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 예약 발송 저장소 (#1275): 만들기, 최근 목록, 취소, 보낼 차례 찾기, 선점(기다림 > 보내는 중), 결과 남기기
 * 상태 바꾸기는 조건부 update 한 줄: 두 인스턴스가 같은 예약을 동시에 보내지 않음, 보내는 중인 예약은 취소 안 됨
 */
@Service
public class ScheduledAdminPushStore {

  // 관리자 목록 최대 줄 수
  public static final int RECENT_LIST_SIZE = 50;

  private final ScheduledAdminPushRepository scheduledAdminPushRepository;
  private final Clock clock;

  @Autowired
  public ScheduledAdminPushStore(ScheduledAdminPushRepository scheduledAdminPushRepository) {
    this(scheduledAdminPushRepository, Clock.system(NotificationTime.ZONE_ID));
  }

  ScheduledAdminPushStore(ScheduledAdminPushRepository scheduledAdminPushRepository, Clock clock) {
    this.scheduledAdminPushRepository = scheduledAdminPushRepository;
    this.clock = clock;
  }

  /// 기다림 상태로 저장
  public ScheduledAdminPush create(ScheduledAdminPush scheduled) {
    scheduled.setStatus(ScheduledAdminPushStatus.PENDING);
    return scheduledAdminPushRepository.save(scheduled);
  }

  @Transactional(readOnly = true)
  public List<ScheduledAdminPush> findRecent() {
    return scheduledAdminPushRepository.findAllByOrderByScheduledAtDesc(PageRequest.of(0, RECENT_LIST_SIZE));
  }

  @Transactional(readOnly = true)
  public Optional<ScheduledAdminPush> findById(String id) {
    return scheduledAdminPushRepository.findById(id);
  }

  /// 취소: 기다림일 때만 (이미 보내는 중·보냄이면 false)
  public boolean cancel(String id) {
    return scheduledAdminPushRepository.transition(id, ScheduledAdminPushStatus.PENDING,
      ScheduledAdminPushStatus.CANCELED, LocalDateTime.now(clock)) == 1;
  }

  /// 보낼 시각이 지난 기다림 id (오래된 순)
  @Transactional(readOnly = true)
  public List<String> findDueIds(LocalDateTime now) {
    return scheduledAdminPushRepository.findIdsDue(ScheduledAdminPushStatus.PENDING, now);
  }

  /// 선점: 기다림 > 보내는 중 (true 인 한 인스턴스만 보냄)
  public boolean claim(String id) {
    return scheduledAdminPushRepository.transition(id, ScheduledAdminPushStatus.PENDING,
      ScheduledAdminPushStatus.SENDING, LocalDateTime.now(clock)) == 1;
  }

  /// 결과 남기기: 보냄이면 수치, 실패면 사유
  @Transactional
  public void finish(String id, ScheduledAdminPushResult result) {
    scheduledAdminPushRepository.findById(id).ifPresent(scheduled -> {
      scheduled.setStatus(result.isSent() ? ScheduledAdminPushStatus.SENT : ScheduledAdminPushStatus.FAILED);
      scheduled.setAdminMessageId(result.adminMessageId());
      scheduled.setRecipientCount(result.recipientCount());
      scheduled.setRecordedCount(result.recordedCount());
      scheduled.setSentDeviceCount(result.sentDeviceCount());
      scheduled.setFailedDeviceCount(result.failedDeviceCount());
      scheduled.setFailureReason(result.failureReason());
      scheduled.setProcessedAt(LocalDateTime.now(clock));
    });
  }

  /// 예약 한 건 보낸 결과 (실패면 사유 코드만)
  public record ScheduledAdminPushResult(boolean isSent, String adminMessageId, Integer recipientCount,
    Integer recordedCount, Integer sentDeviceCount, Integer failedDeviceCount, String failureReason) {

    public static ScheduledAdminPushResult failed(String failureReason) {
      return new ScheduledAdminPushResult(false, null, null, null, null, null, failureReason);
    }
  }
}
