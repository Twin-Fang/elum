package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.notification.application.dto.request.NotificationSettingRequest;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationSettingResponse;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/// 행이 없을 때 꺼짐으로 답하면 처음 쓰는 보호자가 푸시를 못 받고, 여섯 값 중 하나라도 안 저장되면 끈 알림이 다시 켜진다
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NotificationSettingServiceTest {

  @Mock
  private NotificationSettingRepository notificationSettingRepository;
  @InjectMocks
  private NotificationSettingService notificationSettingService;

  @Test
  @DisplayName("행이 없으면 여섯 값이 모두 true 다")
  void noRow_returnsAllTrue() {
    when(notificationSettingRepository.findById("m1")).thenReturn(Optional.empty());

    NotificationSettingResponse response = notificationSettingService.get("m1");

    assertThat(response).isEqualTo(new NotificationSettingResponse(true, true, true, true, true, true));
  }

  @Test
  @DisplayName("저장하면 여섯 값이 모두 반영되고 같은 상태를 돌려준다")
  void update_persistsAllSixFlags() {
    when(notificationSettingRepository.findById("m1")).thenReturn(Optional.empty());
    when(notificationSettingRepository.save(any(NotificationSetting.class))).thenAnswer(call -> call.getArgument(0));

    NotificationSettingResponse response = notificationSettingService.update("m1",
      new NotificationSettingRequest(true, false, true, false, true, false));

    assertThat(response).isEqualTo(new NotificationSettingResponse(true, false, true, false, true, false));
  }
}
