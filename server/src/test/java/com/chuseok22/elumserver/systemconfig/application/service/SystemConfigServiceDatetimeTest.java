package com.chuseok22.elumserver.systemconfig.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
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
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 날짜시간 설정(신규가입 PRO 이벤트 기간): 형식 검사는 유지하고, 비우기(= 이벤트 끄기)와 기본값 복원은 허용
 */
@ExtendWith(MockitoExtension.class)
class SystemConfigServiceDatetimeTest {

  @Mock private SystemConfigRepository systemConfigRepository;
  @Mock private SystemConfigHistoryRepository historyRepository;

  private SystemConfigService service;

  @BeforeEach
  void setUp() {
    service = new SystemConfigService(systemConfigRepository,
      new GeminiProperties("key", null, "text", "image", 1000),
      new LocalLlmProperties(true, null, "/chat", "key", "model", 1000),
      new SecretCipher(new SecretProperties("test-master-key")), historyRepository);
    lenient().when(systemConfigRepository.findAll()).thenReturn(List.of());
  }

  @Test
  @DisplayName("날짜를 비워 저장하면 비어 있는 값으로 저장돼 이벤트가 꺼진다")
  void blankDatetime_isStored() {
    SystemConfig stored = new SystemConfig();
    stored.setConfigKey(ConfigKey.SIGNUP_PRO_EVENT_END_AT);
    stored.setConfigValue("2026-10-26T00:00");
    when(systemConfigRepository.findByConfigKey(ConfigKey.SIGNUP_PRO_EVENT_END_AT)).thenReturn(Optional.of(stored));

    service.update(ConfigKey.SIGNUP_PRO_EVENT_END_AT, "", "admin", null);

    assertThat(stored.getConfigValue()).isEmpty();
    verify(systemConfigRepository).save(stored);
  }

  @Test
  @DisplayName("읽을 수 없는 날짜 글자는 여전히 저장되지 않는다")
  void brokenDatetime_isRejected() {
    assertThatThrownBy(() -> service.update(ConfigKey.SIGNUP_PRO_EVENT_START_AT, "어제", "admin", null))
      .isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("저장값이 비어 기본값으로 폴백되는 키는 화면에서 기본값과 같다고 본다")
  void blankStoredValue_fallsBackToDefault_notChanged() {
    SystemConfig stored = new SystemConfig();
    stored.setConfigKey(ConfigKey.FREE_ADS_REMOVED);
    stored.setConfigValue("");
    when(systemConfigRepository.findAll()).thenReturn(List.of(stored));

    SystemConfigView view = service.getAllViews().stream()
      .filter(candidate -> candidate.key().equals(ConfigKey.FREE_ADS_REMOVED.name())).findFirst().orElseThrow();

    assertThat(view.value()).isEqualTo("false");
    assertThat(view.changed()).isFalse();
  }

  @Test
  @DisplayName("yml 로 바뀐 모델 기본값이 있으면 그 값이 기본값이고, 같으면 같다고 본다")
  void ymlDefault_isEffectiveDefault() {
    SystemConfigView view = service.getAllViews().stream()
      .filter(candidate -> candidate.key().equals(ConfigKey.GEMINI_TEXT_MODEL.name())).findFirst().orElseThrow();

    assertThat(view.defaultValue()).isEqualTo("text");
    assertThat(view.changed()).isFalse();
  }
}
