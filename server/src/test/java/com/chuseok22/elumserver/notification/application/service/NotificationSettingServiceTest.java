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
  @DisplayName("행이 없으면 여덟 값이 모두 true 다")
  void noRow_returnsAllTrue() {
    when(notificationSettingRepository.findById("m1")).thenReturn(Optional.empty());

    NotificationSettingResponse response = notificationSettingService.get("m1");

    assertThat(response).isEqualTo(new NotificationSettingResponse(true, true, true, true, true, true, true, true));
  }

  @Test
  @DisplayName("저장하면 여덟 값이 모두 반영되고 같은 상태를 돌려준다")
  void update_persistsAllEightFlags() {
    when(notificationSettingRepository.findById("m1")).thenReturn(Optional.empty());
    when(notificationSettingRepository.save(any(NotificationSetting.class))).thenAnswer(call -> call.getArgument(0));

    NotificationSettingResponse response = notificationSettingService.update("m1",
      new NotificationSettingRequest(true, false, true, false, true, false, false, true));

    assertThat(response).isEqualTo(new NotificationSettingResponse(true, false, true, false, true, false, false, true));
  }

  @Test
  @DisplayName("옛 앱이 이야기 두 값을 안 보내면(null) 저장된 값을 그대로 둔다")
  void update_nullTalkFlags_keepsStoredValues() {
    NotificationSetting stored = new NotificationSetting();
    stored.setMemberId("m1");
    stored.setTalkCommentedEnabled(false);
    stored.setTalkImportedEnabled(false);
    when(notificationSettingRepository.findById("m1")).thenReturn(Optional.of(stored));
    when(notificationSettingRepository.save(any(NotificationSetting.class))).thenAnswer(call -> call.getArgument(0));

    NotificationSettingResponse response = notificationSettingService.update("m1",
      new NotificationSettingRequest(true, true, true, true, true, true, null, null));

    assertThat(response.talkCommented()).isFalse();
    assertThat(response.talkImported()).isFalse();
  }
}
