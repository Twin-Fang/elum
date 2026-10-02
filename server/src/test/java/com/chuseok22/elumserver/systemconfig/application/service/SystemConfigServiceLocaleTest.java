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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SystemConfigServiceLocaleTest {

  @Mock
  private SystemConfigRepository systemConfigRepository;

  @Mock
  private SystemConfigHistoryRepository systemConfigHistoryRepository;

  private SystemConfigService service;

  @BeforeEach
  void setUp() {
    service = new SystemConfigService(
      systemConfigRepository,
      new GeminiProperties("key", null, "yml-text-model", "yml-image-model", 1000),
      new LocalLlmProperties(true, null, "/chat", "key", "yml-local-model", 1000),
      new SecretCipher(new SecretProperties("test-master-key")),
      systemConfigHistoryRepository);
    when(systemConfigRepository.findAll()).thenReturn(List.of());
  }

  @Test
  @DisplayName("저장된 값이 없으면 ko 가 기본값이다")
  void default_isKo() {
    assertThat(service.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).isEqualTo("ko");
  }

  @Test
  @DisplayName("저장하면 정규화한 값이 들어간다 — ko 를 앞에 붙이고 순서를 고정한다")
  void update_savesNormalizedValue() {
    service.update(ConfigKey.ENABLED_CONTENT_LOCALES, "EN, ja");

    ArgumentCaptor<SystemConfig> saved = ArgumentCaptor.forClass(SystemConfig.class);
    verify(systemConfigRepository).save(saved.capture());
    assertThat(saved.getValue().getConfigValue()).isEqualTo("ko,en,ja");
  }

  @org.junit.jupiter.params.ParameterizedTest
  @org.junit.jupiter.params.provider.CsvSource(delimiter = '|', value = {
    "ko|ko", "  EN  |ko,en", "ja,ko,ja|ko,ja", "ES, ja , EN|ko,en,ja,es", "ko,,en|ko,en"})
  @DisplayName("공백·대소문자·중복·순서는 정규화해서 저장한다")
  void update_normalizes(String input, String expected) {
    service.update(ConfigKey.ENABLED_CONTENT_LOCALES, input);

    ArgumentCaptor<SystemConfig> saved = ArgumentCaptor.forClass(SystemConfig.class);
    verify(systemConfigRepository).save(saved.capture());
    assertThat(saved.getValue().getConfigValue()).isEqualTo(expected);
  }

  @org.junit.jupiter.params.ParameterizedTest
  @org.junit.jupiter.params.provider.ValueSource(strings = {"xx", "ko,xx", "zh-Hans", ",", "ko;en"})
  @DisplayName("미지원 코드와 구분자 오류는 각각 거절한다")
  void update_rejectsEach(String input) {
    assertThatThrownBy(() -> service.update(ConfigKey.ENABLED_CONTENT_LOCALES, input))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    verify(systemConfigRepository, never()).save(any());
  }

  @Test
  @DisplayName("모르는 코드는 저장하지 않는다")
  void update_rejectsUnknownCode() {
    assertThatThrownBy(() -> service.update(ConfigKey.ENABLED_CONTENT_LOCALES, "xx"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    verify(systemConfigRepository, never()).save(any());
  }

  @Test
  @DisplayName("빈 값도 저장하지 않는다 — 켠 언어가 통째로 사라지지 않게")
  void update_rejectsBlank() {
    assertThatThrownBy(() -> service.update(ConfigKey.ENABLED_CONTENT_LOCALES, "  "))
      .isInstanceOf(CustomException.class);
    verify(systemConfigRepository, never()).save(any());
  }
}
