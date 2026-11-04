package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.ClaudeApiKey;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Claude 키 목록 (#1083): 우선순위 순서 보존, 중복·형식 거부, 저장값(비밀값 한 칸) 왕복
 * 깨지면: 관리자가 순서를 바꿨는데 다른 키가 먼저 쓰이거나, 같은 키가 두 번 들어가 넘김이 무의미해짐
 */
class ClaudeApiKeyServiceTest {

  private static final String KEY_A = "sk-ant-api03-aaaaaaaaaaaaaaaaaaaaaaaa";
  private static final String KEY_B = "sk-ant-api03-bbbbbbbbbbbbbbbbbbbbbbbb";

  private final AtomicReference<String> storedSecret = new AtomicReference<>("");
  private SystemConfigService config;
  private ClaudeApiKeyService service;

  @BeforeEach
  void setUp() {
    config = mock(SystemConfigService.class);
    when(config.getSecret(ConfigKey.CLAUDE_API_KEYS)).thenAnswer(inv -> storedSecret.get());
    doAnswer(inv -> { storedSecret.set(inv.getArgument(1)); return null; })
      .when(config).update(eq(ConfigKey.CLAUDE_API_KEYS), any(), any(), any());
    doAnswer(inv -> { storedSecret.set(""); return null; })
      .when(config).resetToDefault(eq(ConfigKey.CLAUDE_API_KEYS), any(), any());
    service = new ClaudeApiKeyService(config);
  }

  @Test
  @DisplayName("추가한 순서가 우선순위 — 내리면 순서가 바뀌고 끄면 호출 대상에서 빠진다")
  void addMoveDisable_keepsOrder() {
    service.add("회사 키", KEY_A, "admin");
    service.add("개인 키", KEY_B, "admin");
    String companyKeyId = service.keys().get(0).id();

    assertThat(service.keys()).extracting(ClaudeApiKey::nickname).containsExactly("회사 키", "개인 키");
    service.move(companyKeyId, false, "admin");
    assertThat(service.keys()).extracting(ClaudeApiKey::nickname).containsExactly("개인 키", "회사 키");
    service.setEnabled(companyKeyId, false, "admin");
    assertThat(service.enabledKeys()).extracting(ClaudeApiKey::nickname).containsExactly("개인 키");
  }

  @Test
  @DisplayName("같은 키·같은 별명·공백 섞인 키는 거부한다")
  void duplicatesAndMalformed_rejected() {
    service.add("회사 키", KEY_A, "admin");

    assertThatThrownBy(() -> service.add("다른 이름", KEY_A, "admin"))
      .isInstanceOf(CustomException.class).hasFieldOrPropertyWithValue("errorCode", ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    assertThatThrownBy(() -> service.add("회사 키", KEY_B, "admin")).isInstanceOf(CustomException.class);
    assertThatThrownBy(() -> service.add("새 키", "sk-ant api03 with space 0000000", "admin")).isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("마지막 키를 지우면 비밀값을 비운다 (빈 값 저장은 '그대로 두기'라 복원으로 지움)")
  void removeLast_clearsSecret() {
    service.add("회사 키", KEY_A, "admin");

    service.remove(service.keys().get(0).id(), "admin");

    verify(config).resetToDefault(eq(ConfigKey.CLAUDE_API_KEYS), eq("admin"), any());
    assertThat(service.keys()).isEmpty();
  }

  @Test
  @DisplayName("저장값이 망가져 있으면 빈 목록 — 키 없음 상태로 두고 서버는 계속 돈다")
  void unreadableSecret_isEmpty() {
    storedSecret.set("not json");

    assertThat(service.keys()).isEmpty();
    assertThat(service.hasEnabledKey()).isFalse();
  }

  @Test
  @DisplayName("화면용 가린 키는 끝 4자리만 보인다")
  void maskedKey_showsLastFourOnly() {
    assertThat(new ClaudeApiKey("id", "n", KEY_A, true).maskedKey()).isEqualTo("••••aaaa").doesNotContain("sk-ant");
  }
}
