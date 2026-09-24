package com.chuseok22.elumserver.systemconfig.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.SecretProperties;
import com.chuseok22.elumserver.common.infrastructure.security.SecretCipher;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigHistoryRepository;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class SystemConfigServiceTest {

  @Mock
  private SystemConfigRepository systemConfigRepository;

  @Mock
  private SystemConfigHistoryRepository systemConfigHistoryRepository;

  private SystemConfigService systemConfigService;

  @BeforeEach
  void setUp() {
    // properties는 record라 목 대신 실제 값으로 만든다 — yml 기반 기본값 우선 규칙 검증에 사용.
    GeminiProperties geminiProperties = new GeminiProperties("key", null, "yml-text-model", "yml-image-model", 1000);
    LocalLlmProperties localLlmProperties = new LocalLlmProperties(true, null, "/chat", "key", "yml-local-model", 1000);
    // 비밀값 암호화는 목이 아니라 실물을 쓴다 — 넣은 값이 그대로 돌아오는지가 핵심이라
    // 목으로 흉내 내면 정작 검증하려던 것을 못 본다.
    SecretCipher secretCipher = new SecretCipher(new SecretProperties("test-master-key"));
    systemConfigService = new SystemConfigService(
      systemConfigRepository, geminiProperties, localLlmProperties, secretCipher, systemConfigHistoryRepository);
  }

  private SystemConfig config(ConfigKey key, String value) {
    SystemConfig config = new SystemConfig();
    config.setConfigKey(key);
    config.setConfigValue(value);
    return config;
  }

  @Test
  @DisplayName("getString은 DB에 저장된 값을 반환한다")
  void getString_storedValue_returnsIt() {
    when(systemConfigRepository.findAll())
      .thenReturn(List.of(config(ConfigKey.GEMINI_TEXT_MODEL, "gemini-custom")));

    assertThat(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).isEqualTo("gemini-custom");
  }

  @Test
  @DisplayName("저장된 값이 없으면 yml 값이 기본값으로 우선한다 (모델 키)")
  void getString_missing_modelKeyFallsBackToProperties() {
    when(systemConfigRepository.findAll()).thenReturn(List.of());

    assertThat(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).isEqualTo("yml-text-model");
    assertThat(systemConfigService.getString(ConfigKey.GEMINI_IMAGE_MODEL)).isEqualTo("yml-image-model");
    assertThat(systemConfigService.getString(ConfigKey.LOCAL_LLM_MODEL)).isEqualTo("yml-local-model");
  }

  @Test
  @DisplayName("모델 키가 아닌 설정은 enum 기본값으로 폴백한다")
  void getString_missing_nonModelKeyFallsBackToEnumDefault() {
    when(systemConfigRepository.findAll()).thenReturn(List.of());

    assertThat(systemConfigService.getString(ConfigKey.GEMINI_IMAGE_ASPECT_RATIO)).isEqualTo("4:3");
    assertThat(systemConfigService.getDouble(ConfigKey.PRICE_GEMINI_TEXT_INPUT_PER_1M)).isEqualTo(0.30);
  }

  @Test
  @DisplayName("저장된 값이 손상돼 숫자 파싱에 실패하면 기본값으로 폴백한다")
  void getDouble_corruptedValue_fallsBackToDefault() {
    when(systemConfigRepository.findAll())
      .thenReturn(List.of(config(ConfigKey.GEMINI_TEXT_TEMPERATURE, "숫자아님")));

    assertThat(systemConfigService.getDouble(ConfigKey.GEMINI_TEXT_TEMPERATURE)).isEqualTo(0.0);
  }

  @Test
  @DisplayName("update는 값을 저장하고 캐시를 즉시 갱신한다")
  void update_validValue_savesAndRefreshesCache() {
    when(systemConfigRepository.findByConfigKey(ConfigKey.GEMINI_TEXT_MODEL)).thenReturn(Optional.empty());
    when(systemConfigRepository.findAll())
      .thenReturn(List.of(config(ConfigKey.GEMINI_TEXT_MODEL, "gemini-updated")));

    systemConfigService.update(ConfigKey.GEMINI_TEXT_MODEL, "gemini-updated");

    ArgumentCaptor<SystemConfig> captor = ArgumentCaptor.forClass(SystemConfig.class);
    verify(systemConfigRepository).save(captor.capture());
    assertThat(captor.getValue().getConfigValue()).isEqualTo("gemini-updated");
    // TTL이 남았어도 update 직후에는 새 값이 바로 보여야 한다.
    assertThat(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).isEqualTo("gemini-updated");
  }

  @Test
  @DisplayName("SELECT 타입은 허용값 외 입력을 거부한다")
  void update_selectTypeWithNotAllowedValue_throws() {
    assertThatThrownBy(() -> systemConfigService.update(ConfigKey.GEMINI_IMAGE_ASPECT_RATIO, "21:9"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE));
    verify(systemConfigRepository, never()).save(any());
  }

  @Test
  @DisplayName("DECIMAL 타입은 숫자가 아닌 입력을 거부한다")
  void update_decimalTypeWithNonNumber_throws() {
    assertThatThrownBy(() -> systemConfigService.update(ConfigKey.GEMINI_TEXT_TEMPERATURE, "높게"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE));
  }

  @Test
  @DisplayName("빈 값 입력은 거부한다")
  void update_blankValue_throws() {
    assertThatThrownBy(() -> systemConfigService.update(ConfigKey.GEMINI_TEXT_MODEL, "  "))
      .isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("resetToDefault는 기본값으로 되돌린다")
  void resetToDefault_savesDefaultValue() {
    when(systemConfigRepository.findByConfigKey(ConfigKey.GEMINI_IMAGE_ASPECT_RATIO)).thenReturn(Optional.empty());
    when(systemConfigRepository.findAll()).thenReturn(List.of());

    systemConfigService.resetToDefault(ConfigKey.GEMINI_IMAGE_ASPECT_RATIO);

    ArgumentCaptor<SystemConfig> captor = ArgumentCaptor.forClass(SystemConfig.class);
    verify(systemConfigRepository).save(captor.capture());
    assertThat(captor.getValue().getConfigValue()).isEqualTo("4:3");
  }

  @Test
  @DisplayName("캐시 리로드가 실패해도 예외 없이 기본값으로 동작한다")
  void getString_reloadFailure_stillReturnsDefault() {
    when(systemConfigRepository.findAll()).thenThrow(new RuntimeException("DB down"));

    assertThat(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).isEqualTo("yml-text-model");
  }

  @Test
  @DisplayName("getAllViews는 모든 키를 노출하고 변경 여부를 표시한다")
  void getAllViews_marksChangedValues() {
    when(systemConfigRepository.findAll())
      .thenReturn(List.of(config(ConfigKey.GEMINI_TEXT_MODEL, "gemini-changed")));

    List<SystemConfigView> views = systemConfigService.getAllViews();

    assertThat(views).hasSize(ConfigKey.values().length);
    SystemConfigView textModel = views.stream()
      .filter(view -> view.key().equals(ConfigKey.GEMINI_TEXT_MODEL.name())).findFirst().orElseThrow();
    assertThat(textModel.changed()).isTrue();
    SystemConfigView aspectRatio = views.stream()
      .filter(view -> view.key().equals(ConfigKey.GEMINI_IMAGE_ASPECT_RATIO.name())).findFirst().orElseThrow();
    assertThat(aspectRatio.changed()).isFalse();
  }

  @Test
  @DisplayName("범위가 있는 시간값은 범위를 벗어나면 거절한다 — 0 은 앱이 끝없이 기다리게 만든다")
  void update_integerOutOfRange_rejected() {
    for (String bad : List.of("0", "-1", "999", "15001", "abc")) {
      assertThatThrownBy(() -> systemConfigService.update(ConfigKey.APP_CONSENT_FETCH_TIMEOUT_MS, bad))
        .as("값 %s", bad)
        .isInstanceOf(CustomException.class)
        .extracting("errorCode").isEqualTo(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    verify(systemConfigRepository, never()).save(any());
  }

  @Test
  @DisplayName("범위 안의 시간값은 저장한다 — 경계값 포함")
  void update_integerInRange_saved() {
    when(systemConfigRepository.findByConfigKey(ConfigKey.APP_CONSENT_FETCH_TIMEOUT_MS)).thenReturn(Optional.empty());
    systemConfigService.update(ConfigKey.APP_CONSENT_FETCH_TIMEOUT_MS, "1000");
    systemConfigService.update(ConfigKey.APP_CONSENT_FETCH_TIMEOUT_MS, "15000");
    verify(systemConfigRepository, org.mockito.Mockito.times(2)).save(any());
  }

  @Test
  @DisplayName("범위가 없는 정수는 예전처럼 받는다 — 플랜 한도의 -1(무제한)")
  void update_integerWithoutRange_keepsOldBehavior() {
    when(systemConfigRepository.findByConfigKey(ConfigKey.FREE_ROUTINE_MAX_COUNT)).thenReturn(Optional.empty());
    systemConfigService.update(ConfigKey.FREE_ROUTINE_MAX_COUNT, "-1");
    verify(systemConfigRepository).save(any());
  }

  @Test
  @DisplayName("앱 시간값의 기본값은 앱 코드 기본값과 같다 — 서버를 못 봐도 같은 값으로 돈다")
  void appTuningDefaults_matchClient() {
    assertThat(ConfigKey.APP_CONNECT_TIMEOUT_MS.getDefaultValue()).isEqualTo("10000");
    assertThat(ConfigKey.APP_RECEIVE_TIMEOUT_MS.getDefaultValue()).isEqualTo("60000");
    assertThat(ConfigKey.APP_LOADING_MAX_WAIT_MS.getDefaultValue()).isEqualTo("45000");
    assertThat(ConfigKey.APP_CONSENT_FETCH_TIMEOUT_MS.getDefaultValue()).isEqualTo("3000");
    assertThat(ConfigKey.APP_DLP_MIN_DELAY_MS.getDefaultValue()).isEqualTo("1500");
  }

  // ── 스토어 주소 (#416) ──
  // 강제 업데이트 화면이 이 주소로 사용자를 보낸다. 엉뚱한 주소가 저장되면 막힌 사용자가
  // 다른 곳으로 가므로, 플랫폼에 맞는 공식 스토어 주소만 받는다.

  @Test
  @DisplayName("iOS 스토어 주소는 App Store 주소를 받는다")
  void update_iosStoreUrl_appStore_saves() {
    when(systemConfigRepository.findByConfigKey(ConfigKey.IOS_STORE_URL)).thenReturn(Optional.empty());

    systemConfigService.update(ConfigKey.IOS_STORE_URL, " https://apps.apple.com/kr/app/id6792970508 ");
    systemConfigService.update(ConfigKey.IOS_STORE_URL, "itms-apps://apps.apple.com/app/id6792970508");

    verify(systemConfigRepository, org.mockito.Mockito.times(2)).save(any());
  }

  @Test
  @DisplayName("Android 스토어 주소는 Play 스토어 주소를 받는다")
  void update_androidStoreUrl_playStore_saves() {
    when(systemConfigRepository.findByConfigKey(ConfigKey.ANDROID_STORE_URL)).thenReturn(Optional.empty());

    systemConfigService.update(ConfigKey.ANDROID_STORE_URL,
      "https://play.google.com/store/apps/details?id=kr.twinfang.elum");
    systemConfigService.update(ConfigKey.ANDROID_STORE_URL, "market://details?id=kr.twinfang.elum");

    verify(systemConfigRepository, org.mockito.Mockito.times(2)).save(any());
  }

  @Test
  @DisplayName("스토어 주소가 아니거나 플랫폼이 다르면 거부한다")
  void update_storeUrl_notStore_throws() {
    List<String> iosRejected = List.of(
      "http://apps.apple.com/app/id6792970508",        // https 가 아니다
      "https://apps.apple.com.evil.com/app/id1",        // 호스트를 흉내 냈다
      "https://example.com/elum",
      "https://play.google.com/store/apps/details?id=kr.twinfang.elum", // 다른 플랫폼
      "apps.apple.com/app/id6792970508",                 // 스킴이 없다
      "javascript:alert(1)"
    );
    for (String value : iosRejected) {
      assertThatThrownBy(() -> systemConfigService.update(ConfigKey.IOS_STORE_URL, value))
        .as(value)
        .isInstanceOf(CustomException.class)
        .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
          .isEqualTo(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE));
    }
    assertThatThrownBy(() -> systemConfigService.update(ConfigKey.ANDROID_STORE_URL,
      "https://apps.apple.com/kr/app/id6792970508"))
      .isInstanceOf(CustomException.class);
    verify(systemConfigRepository, never()).save(any());
  }

  @Test
  @DisplayName("스토어 주소 기본값은 비어 있다 — 비면 앱에 넣어 둔 주소를 쓴다")
  void storeUrl_defaultIsEmpty() {
    assertThat(ConfigKey.IOS_STORE_URL.getDefaultValue()).isEmpty();
    assertThat(ConfigKey.ANDROID_STORE_URL.getDefaultValue()).isEmpty();
  }
}
