package com.chuseok22.elumserver.systemconfig.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.application.dto.response.AppStatusResponse;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
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
 * 새 서버 주소: 빈 설정 > null, 허용 주소 > 그대로 (#831)
 * 신규 판매: 판매 켜기 AND 검증 켜기, 설정 읽기 실패 > false (#1132)
 */
@ExtendWith(MockitoExtension.class)
class AppStatusControllerTest {

  @Mock
  private SystemConfigService systemConfigService;

  private AppStatusController controller;

  @BeforeEach
  void setUp() {
    controller = new AppStatusController(systemConfigService, new MigrationLock(systemConfigService));
    // 이 테스트가 보지 않는 값은 기본값처럼 채운다
    lenient().when(systemConfigService.getString(any())).thenReturn("");
    lenient().when(systemConfigService.getInt(any())).thenReturn(1000);
    lenient().when(systemConfigService.getBoolean(any())).thenReturn(false);
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

  @Test
  @DisplayName("새 서버 주소가 비어 있으면 null — 앱이 지금 주소를 유지한다")
  void status_blankServerAddress_sendsNull() {
    when(systemConfigService.getString(ConfigKey.APP_API_BASE_URL)).thenReturn("  ");

    AppStatusResponse body = controller.status().getBody();

    assertThat(body).isNotNull();
    assertThat(body.server()).isNotNull();
    assertThat(body.server().apiBaseUrl()).isNull();
  }

  @Test
  @DisplayName("새 서버 주소가 있으면 끝 / 를 뗀 값을 보낸다 — 앱이 확인 후 옮겨 간다")
  void status_serverAddressSet_sendsValue() {
    when(systemConfigService.getString(ConfigKey.APP_API_BASE_URL)).thenReturn("https://api.elum.suhsaechan.kr/");

    AppStatusResponse body = controller.status().getBody();

    assertThat(body).isNotNull();
    assertThat(body.server().apiBaseUrl()).isEqualTo("https://api.elum.suhsaechan.kr");
  }

  @Test
  @DisplayName("허용 도메인 밖 주소는 null — DB 를 직접 고쳐도 사용자 토큰이 엉뚱한 곳으로 가지 않는다")
  void status_notAllowedServerAddress_sendsNull() {
    when(systemConfigService.getString(ConfigKey.APP_API_BASE_URL)).thenReturn("https://evil.example.com");

    AppStatusResponse body = controller.status().getBody();

    assertThat(body).isNotNull();
    assertThat(body.server().apiBaseUrl()).isNull();
  }

  @Test
  @DisplayName("검증이 꺼진 플랫폼은 판매를 켜도 false — 검증 못 하는 결제 화면을 열지 않는다")
  void status_sellingOnButVerificationOff_closesSales() {
    when(systemConfigService.getBoolean(ConfigKey.SUBSCRIPTION_APPLE_SELLING_ENABLED)).thenReturn(true);
    when(systemConfigService.getBoolean(ConfigKey.SUBSCRIPTION_APPLE_ENABLED)).thenReturn(false);

    AppStatusResponse body = controller.status().getBody();

    assertThat(body).isNotNull();
    assertThat(body.sales().ios()).isFalse();
  }

  @Test
  @DisplayName("판매·검증 모두 켜진 플랫폼만 true — 플랫폼끼리 섞이지 않는다")
  void status_sellingAndVerificationOn_opensOnlyThatPlatform() {
    when(systemConfigService.getBoolean(ConfigKey.SUBSCRIPTION_APPLE_SELLING_ENABLED)).thenReturn(true);
    when(systemConfigService.getBoolean(ConfigKey.SUBSCRIPTION_APPLE_ENABLED)).thenReturn(true);

    AppStatusResponse body = controller.status().getBody();

    assertThat(body).isNotNull();
    assertThat(body.sales().ios()).isTrue();
    assertThat(body.sales().android()).isFalse();
  }

  @Test
  @DisplayName("판매 설정을 못 읽으면 false — 상태 응답 자체는 나간다")
  void status_salesConfigReadFails_closesSalesAndStillResponds() {
    when(systemConfigService.getBoolean(ConfigKey.SUBSCRIPTION_GOOGLE_SELLING_ENABLED))
      .thenThrow(new IllegalStateException("db down"));

    AppStatusResponse body = controller.status().getBody();

    assertThat(body).isNotNull();
    assertThat(body.sales().android()).isFalse();
  }
}
