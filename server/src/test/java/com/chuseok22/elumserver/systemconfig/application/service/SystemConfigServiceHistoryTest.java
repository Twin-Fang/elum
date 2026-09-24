package com.chuseok22.elumserver.systemconfig.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.SecretProperties;
import com.chuseok22.elumserver.common.infrastructure.security.SecretCipher;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
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

/**
 * 시스템 설정 변경 이력 (#407 Task S6). 누가 무엇을 무엇으로 바꿨는지 남기고, 비밀값은 가린다.
 */
@ExtendWith(MockitoExtension.class)
class SystemConfigServiceHistoryTest {

  @Mock private SystemConfigRepository systemConfigRepository;
  @Mock private SystemConfigHistoryRepository historyRepository;

  private SystemConfigService service;
  private SecretCipher secretCipher;

  @BeforeEach
  void setUp() {
    GeminiProperties geminiProperties = new GeminiProperties("key", null, "yml-text-model", "yml-image-model", 1000);
    LocalLlmProperties localLlmProperties = new LocalLlmProperties(true, null, "/chat", "key", "yml-local-model", 1000);
    secretCipher = new SecretCipher(new SecretProperties("test-master-key"));
    service = new SystemConfigService(
      systemConfigRepository, geminiProperties, localLlmProperties, secretCipher, historyRepository);
    lenient().when(systemConfigRepository.findAll()).thenReturn(List.of());
  }

  private SystemConfig stored(ConfigKey key, String value) {
    SystemConfig config = new SystemConfig();
    config.setConfigKey(key);
    config.setConfigValue(value);
    when(systemConfigRepository.findByConfigKey(key)).thenReturn(Optional.of(config));
    return config;
  }

  private SystemConfigHistory recorded() {
    ArgumentCaptor<SystemConfigHistory> captor = ArgumentCaptor.forClass(SystemConfigHistory.class);
    verify(historyRepository).save(captor.capture());
    return captor.getValue();
  }

  @Test
  @DisplayName("이전 값 → 새 값 · 변경자 · 사유를 남긴다")
  void update_recordsOldNewActorReason() {
    stored(ConfigKey.GEMINI_TEXT_MODEL, "gemini-old");

    service.update(ConfigKey.GEMINI_TEXT_MODEL, "gemini-new", "kimchi", "  단가 인하  ");

    SystemConfigHistory history = recorded();
    assertThat(history.getConfigKey()).isEqualTo("GEMINI_TEXT_MODEL");
    assertThat(history.getOldValue()).isEqualTo("gemini-old");
    assertThat(history.getNewValue()).isEqualTo("gemini-new");
    assertThat(history.getChangedBy()).isEqualTo("kimchi");
    assertThat(history.getReason()).isEqualTo("단가 인하");
  }

  @Test
  @DisplayName("저장값이 없으면 기본값이 이전 값이다 — 사람이 화면에서 본 값")
  void update_noStoredValue_oldIsDefault() {
    when(systemConfigRepository.findByConfigKey(ConfigKey.GEMINI_TEXT_MODEL)).thenReturn(Optional.empty());

    service.update(ConfigKey.GEMINI_TEXT_MODEL, "gemini-new", "kimchi", null);

    SystemConfigHistory history = recorded();
    assertThat(history.getOldValue()).isEqualTo("yml-text-model");
    assertThat(history.getReason()).isNull();
  }

  @Test
  @DisplayName("값이 그대로면 이력을 남기지 않는다")
  void update_unchanged_noHistory() {
    stored(ConfigKey.GEMINI_TEXT_MODEL, "gemini-same");

    service.update(ConfigKey.GEMINI_TEXT_MODEL, " gemini-same ", "kimchi", "다시 저장");

    verify(historyRepository, never()).save(any());
  }

  @Test
  @DisplayName("변경자를 모르면(코드가 바꾼 것) system 으로 남긴다")
  void update_withoutActor_recordsSystem() {
    stored(ConfigKey.GEMINI_TEXT_MODEL, "gemini-old");

    service.update(ConfigKey.GEMINI_TEXT_MODEL, "gemini-new");

    assertThat(recorded().getChangedBy()).isEqualTo("system");
  }

  @Test
  @DisplayName("비밀값은 평문도 암호문도 남기지 않고 •••• 로만 적는다")
  void update_secret_masked() {
    stored(ConfigKey.OPENAI_API_KEY, secretCipher.encrypt("old-secret"));

    service.update(ConfigKey.OPENAI_API_KEY, "new-secret", "kimchi", null);

    SystemConfigHistory history = recorded();
    assertThat(history.getOldValue()).isEqualTo("••••");
    assertThat(history.getNewValue()).isEqualTo("••••");
    assertThat(history.getOldValue() + history.getNewValue()).doesNotContain("secret");
  }

  @Test
  @DisplayName("처음 넣는 비밀값은 (없음) → •••• 이고, 같은 비밀값을 다시 넣으면 이력이 없다")
  void update_secret_firstSetAndUnchanged() {
    when(systemConfigRepository.findByConfigKey(ConfigKey.OPENAI_API_KEY)).thenReturn(Optional.empty());
    service.update(ConfigKey.OPENAI_API_KEY, "new-secret", "kimchi", null);
    SystemConfigHistory first = recorded();
    assertThat(first.getOldValue()).isEmpty();
    assertThat(first.getNewValue()).isEqualTo("••••");

    org.mockito.Mockito.clearInvocations(historyRepository);
    stored(ConfigKey.OPENAI_API_KEY, secretCipher.encrypt("same"));
    service.update(ConfigKey.OPENAI_API_KEY, "same", "kimchi", null);
    verify(historyRepository, never()).save(any());
  }

  @Test
  @DisplayName("비밀값 지우기(기본값 복원)도 •••• → (없음) 으로 남긴다")
  void resetSecret_recordsRemoval() {
    stored(ConfigKey.OPENAI_API_KEY, secretCipher.encrypt("old-secret"));

    service.resetToDefault(ConfigKey.OPENAI_API_KEY, "kimchi", "키 폐기");

    SystemConfigHistory history = recorded();
    assertThat(history.getOldValue()).isEqualTo("••••");
    assertThat(history.getNewValue()).isEmpty();
    assertThat(history.getReason()).isEqualTo("키 폐기");
  }

  @Test
  @DisplayName("기본값 복원도 이전 → 기본값으로 남긴다")
  void reset_recordsDefault() {
    stored(ConfigKey.GEMINI_TEXT_MODEL, "gemini-custom");

    service.resetToDefault(ConfigKey.GEMINI_TEXT_MODEL, "kimchi", null);

    SystemConfigHistory history = recorded();
    assertThat(history.getOldValue()).isEqualTo("gemini-custom");
    assertThat(history.getNewValue()).isEqualTo("yml-text-model");
  }
}
