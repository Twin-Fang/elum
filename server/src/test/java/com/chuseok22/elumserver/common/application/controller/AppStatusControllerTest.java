package com.chuseok22.elumserver.common.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.application.dto.response.AppStatusResponse;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 앱 상태 응답에 플랫폼별 스토어 주소가 실리는지 (#416).
 *
 * <p>강제 업데이트 화면은 옛 버전 앱에서 뜬다. 주소를 서버가 주면 이미 깔린 앱도
 * 앱을 다시 내지 않고 보낼 곳을 바꿀 수 있다.
 */
@ExtendWith(MockitoExtension.class)
class AppStatusControllerTest {

  @Mock
  private SystemConfigService systemConfigService;

  private AppStatusController controller;

  @BeforeEach
  void setUp() {
    controller = new AppStatusController(systemConfigService);
    // 이 테스트가 보지 않는 값은 기본값처럼 채운다
    lenient().when(systemConfigService.getString(any())).thenReturn("");
    lenient().when(systemConfigService.getInt(any())).thenReturn(1000);
  }

  @Test
  @DisplayName("ios·android 에 각자의 스토어 주소를 싣는다")
  void status_includesStoreUrlPerPlatform() {
    when(systemConfigService.getString(ConfigKey.IOS_STORE_URL))
      .thenReturn("itms-apps://apps.apple.com/app/id6792970508");
    when(systemConfigService.getString(ConfigKey.ANDROID_STORE_URL))
      .thenReturn("https://play.google.com/store/apps/details?id=kr.twinfang.elum");

    AppStatusResponse body = controller.status().getBody();

    assertThat(body).isNotNull();
    assertThat(body.ios().storeUrl()).isEqualTo("itms-apps://apps.apple.com/app/id6792970508");
    assertThat(body.android().storeUrl())
      .isEqualTo("https://play.google.com/store/apps/details?id=kr.twinfang.elum");
  }

  @Test
  @DisplayName("설정이 비어 있으면 빈 값을 보낸다 — 앱이 자기 기본값을 쓴다")
  void status_emptyStoreUrl_sendsEmpty() {
    AppStatusResponse body = controller.status().getBody();

    assertThat(body).isNotNull();
    assertThat(body.ios().storeUrl()).isEmpty();
    assertThat(body.android().storeUrl()).isEmpty();
  }
}
