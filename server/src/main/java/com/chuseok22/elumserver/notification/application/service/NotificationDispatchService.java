package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationDispatch;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 발송 기록 (#1275): 받는 사람마다 기록 열기(푸시 전, id 를 data 에 실음), 기기 결과 채우기, 앱이 알린 열림
 * 기록 실패는 경고 로그만: 알림함·푸시는 그대로 감 (성과 수치만 빠짐)
 */
@Slf4j
@Service
public class NotificationDispatchService {

  private final NotificationDispatchRepository notificationDispatchRepository;
  private final Clock clock;

  @Autowired
  public NotificationDispatchService(NotificationDispatchRepository notificationDispatchRepository) {
    this(notificationDispatchRepository, Clock.system(NotificationTime.ZONE_ID));
  }

  NotificationDispatchService(NotificationDispatchRepository notificationDispatchRepository, Clock clock) {
    this.notificationDispatchRepository = notificationDispatchRepository;
    this.clock = clock;
  }

  /// 받는 사람마다 기록 1줄 > 회원 id 별 기록 id (실패한 사람은 빠짐: 푸시에 dispatchId 없이 감)
  public Map<String, String> open(AdminMessageOrigin origin, String adminMessageId, Collection<String> memberIds) {
    LocalDateTime now = LocalDateTime.now(clock);
    Map<String, String> dispatchIdByMemberId = new HashMap<>();
    for (String memberId : memberIds) {
      try {
        NotificationDispatch dispatch = new NotificationDispatch();
        dispatch.setMemberId(memberId);
        dispatch.setSource(origin.source());
        dispatch.setAutoType(origin.autoType());
        dispatch.setAdminMessageId(adminMessageId);
        dispatch.setSentAt(now);
        dispatchIdByMemberId.put(memberId, notificationDispatchRepository.save(dispatch).getId());
      } catch (RuntimeException exception) {
        log.warn("[notification dispatch] open failed : {}", exception.getClass().getSimpleName());
      }
    }
    return dispatchIdByMemberId;
  }

  /// 기기 결과 채우기 (기기가 없거나 끈 사람은 0·0 그대로)
  public void recordDeviceCounts(Map<String, String> dispatchIdByMemberId, AdminMessageDelivery delivery) {
    try {
      List<NotificationDispatch> dispatches = notificationDispatchRepository.findAllById(dispatchIdByMemberId.values());
      for (NotificationDispatch dispatch : dispatches) {
        AdminMessageDelivery.MemberDeviceCount count = delivery.deviceCountByMemberId().get(dispatch.getMemberId());
        if (count == null) {
          continue;
        }
        dispatch.setSentDeviceCount(count.sentDeviceCount());
        dispatch.setFailedDeviceCount(count.failedDeviceCount());
      }
      notificationDispatchRepository.saveAll(dispatches);
    } catch (RuntimeException exception) {
      log.warn("[notification dispatch] device counts failed : {}", exception.getClass().getSimpleName());
    }
  }

  /// 열림: 내 기록만 (없거나 남의 기록이면 같은 404, 존재 여부를 흘리지 않음), 첫 열림 시각만 남김
  @Transactional
  public void markOpened(String memberId, String dispatchId) {
    NotificationDispatch dispatch = notificationDispatchRepository.findById(dispatchId)
      .filter(row -> row.getMemberId().equals(memberId))
      .orElseThrow(() -> new CustomException(ErrorCode.NOTIFICATION_NOT_FOUND));
    if (dispatch.getOpenedAt() == null) {
      dispatch.setOpenedAt(LocalDateTime.now(clock));
    }
  }
}
