package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.push.PushMessage;
import com.chuseok22.elumserver.notification.infrastructure.push.PushResult;
import com.chuseok22.elumserver.notification.infrastructure.push.PushSender;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.util.List;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 푸시 발송: 푸시 대상만 추림 > 설정 확인(전체 끔, 종류별) > 받는 사람 기기 전부에 순차 발송 > 무효 토큰 기기 삭제
 * 한 건·한 기기의 실패는 로그만 남기고 나머지를 계속 보냄 (재시도 없음)
 */
@Slf4j
@Service
public class PushDispatcher {

  private final NotificationRepository notificationRepository;
  private final NotificationSettingRepository notificationSettingRepository;
  private final PushDeviceRepository pushDeviceRepository;
  private final PushMessageFactory pushMessageFactory;
  private final PushSender pushSender;

  public PushDispatcher(NotificationRepository notificationRepository,
    NotificationSettingRepository notificationSettingRepository, PushDeviceRepository pushDeviceRepository,
    PushMessageFactory pushMessageFactory, PushSender pushSender) {
    this.notificationRepository = notificationRepository;
    this.notificationSettingRepository = notificationSettingRepository;
    this.pushDeviceRepository = pushDeviceRepository;
    this.pushMessageFactory = pushMessageFactory;
    this.pushSender = pushSender;
  }

  @Transactional
  public void dispatch(List<RecordedNotification> recorded, NotificationType type) {
    for (RecordedNotification notification : recorded) {
      if (!notification.shouldPush()) {
        continue;
      }
      try {
        dispatchOne(notification, type);
      } catch (RuntimeException exception) {
        // 한 사람 실패가 다른 사람 발송을 막지 않음
        log.warn("[notification push] failed type={} : {}", type, exception.getClass().getSimpleName());
      }
    }
  }

  private void dispatchOne(RecordedNotification recorded, NotificationType type) {
    if (!isPushEnabled(recorded.recipientMemberId(), type)) {
      return;
    }
    Optional<Notification> notification = notificationRepository.findById(recorded.notificationId());
    if (notification.isEmpty()) {
      return;
    }
    List<PushDevice> devices = pushDeviceRepository.findAllByMemberIdIn(List.of(recorded.recipientMemberId()));
    for (PushDevice device : devices) {
      PushMessage message = pushMessageFactory.create(notification.get(), recorded, device);
      PushResult result = pushSender.send(message);
      if (result == PushResult.INVALID_TOKEN) {
        pushDeviceRepository.deleteByToken(device.getToken());
        log.info("[notification push] invalid token removed : platform={}", device.getPlatform());
      }
    }
  }

  // 설정 행이 없으면 모두 켜짐. 전체 끔이면 종류별 값과 무관하게 꺼짐
  private boolean isPushEnabled(String memberId, NotificationType type) {
    return notificationSettingRepository.findById(memberId)
      .map(setting -> setting.isAllEnabled() && isTypeEnabled(setting, type))
      .orElse(true);
  }

  private boolean isTypeEnabled(NotificationSetting setting, NotificationType type) {
    return switch (type) {
      case ROUTINE_COMPLETED -> setting.isRoutineCompletedEnabled();
      case ROUTINE_SENT_BY_CO_GUARDIAN -> setting.isRoutineSentEnabled();
      case CO_GUARDIAN_JOINED -> setting.isCoGuardianJoinedEnabled();
      case CREDIT_REFILLED -> setting.isCreditRefilledEnabled();
      case FEEDBACK_RESOLVED -> setting.isFeedbackResolvedEnabled();
    };
  }
}
