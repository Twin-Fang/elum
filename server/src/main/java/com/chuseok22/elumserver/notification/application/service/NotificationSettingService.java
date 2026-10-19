package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.application.dto.request.NotificationSettingRequest;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationSettingResponse;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 보호자 푸시 설정: 조회(행 없으면 모두 켜짐), 저장(없으면 만들고 있으면 덮어씀)
@Service
@RequiredArgsConstructor
public class NotificationSettingService {

  private final NotificationSettingRepository notificationSettingRepository;

  @Transactional(readOnly = true)
  public NotificationSettingResponse get(String memberId) {
    return notificationSettingRepository.findById(memberId)
      .map(NotificationSettingResponse::from)
      .orElseGet(NotificationSettingResponse::allEnabledDefault);
  }

  @Transactional
  public NotificationSettingResponse update(String memberId, NotificationSettingRequest request) {
    NotificationSetting setting = notificationSettingRepository.findById(memberId).orElseGet(() -> {
      NotificationSetting created = new NotificationSetting();
      created.setMemberId(memberId);
      return created;
    });
    setting.setAllEnabled(request.allEnabled());
    setting.setRoutineCompletedEnabled(request.routineCompleted());
    setting.setRoutineSentEnabled(request.routineSent());
    setting.setCoGuardianJoinedEnabled(request.coGuardianJoined());
    setting.setCreditRefilledEnabled(request.creditRefilled());
    setting.setFeedbackResolvedEnabled(request.feedbackResolved());
    return NotificationSettingResponse.from(notificationSettingRepository.save(setting));
  }
}
