package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.ClaudeApiKeyService;
import com.chuseok22.elumserver.ai.application.service.ClaudeKeyHealthTracker;
import com.chuseok22.elumserver.ai.core.ClaudeApiKey;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 관리자 텍스트 제공자 순서·Claude 키 (#1083)
 * 깨지면: 키 없는 제공자를 순서에 넣어 일과 생성이 실패하거나, 쓰는 중인 마지막 Claude 키를 지워 Claude 단계가 통째로 실패
 */
class AdminTextProviderServiceTest {

  private TextClientRouter router;
  private SystemConfigService config;
  private ClaudeApiKeyService keyService;
  private TextGenerationClient claude;
  private AdminTextProviderService service;

  @BeforeEach
  void setUp() {
    router = mock(TextClientRouter.class);
    config = mock(SystemConfigService.class);
    keyService = mock(ClaudeApiKeyService.class);
    claude = mock(TextGenerationClient.class);
    TextGenerationClient gemini = mock(TextGenerationClient.class);
    when(gemini.available()).thenReturn(true);
    when(router.of(TextProvider.GEMINI)).thenReturn(Optional.of(gemini));
    when(router.of(TextProvider.CLAUDE)).thenReturn(Optional.of(claude));
    service = new AdminTextProviderService(router, config, keyService, mock(ClaudeKeyHealthTracker.class));
  }

  @Test
  @DisplayName("키 없는 Claude 는 순서에 넣을 수 없다 (E-CFG-003)")
  void addUnavailableProvider_rejected() {
    when(router.chain()).thenReturn(List.of(TextProvider.GEMINI));
    when(claude.available()).thenReturn(false);

    assertThatThrownBy(() -> service.addToChain(TextProvider.CLAUDE, "admin"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.TEXT_PROVIDER_UNAVAILABLE);
    verify(config, never()).update(any(), anyString(), any(), any());
  }

  @Test
  @DisplayName("Claude 를 1번으로 올리면 첫 제공자 = CLAUDE, 대체 = GEMINI 로 저장한다")
  void moveClaudeUp_savesSelectedAndFallbacks() {
    when(router.chain()).thenReturn(List.of(TextProvider.GEMINI, TextProvider.CLAUDE));
    when(claude.available()).thenReturn(true);

    service.moveInChain(TextProvider.CLAUDE, true, "admin");

    verify(config).update(eq(ConfigKey.TEXT_PROVIDER_SELECTED), eq("CLAUDE"), eq("admin"), any());
    verify(config).update(eq(ConfigKey.TEXT_PROVIDER_FALLBACKS), eq("GEMINI"), eq("admin"), any());
  }

  @Test
  @DisplayName("순서에 Claude 가 있으면 마지막 켜진 키는 끄거나 지울 수 없다")
  void lastEnabledKeyInUse_cannotBeDisabledOrRemoved() {
    when(router.chain()).thenReturn(List.of(TextProvider.CLAUDE, TextProvider.GEMINI));
    when(keyService.enabledKeys()).thenReturn(List.of(new ClaudeApiKey("k1", "회사 키", "sk-ant-x", true)));

    assertThatThrownBy(() -> service.setClaudeKeyEnabled("k1", false, "admin")).isInstanceOf(CustomException.class);
    assertThatThrownBy(() -> service.removeClaudeKey("k1", "admin")).isInstanceOf(CustomException.class);
    verify(keyService, never()).remove(any(), any());
  }

  @Test
  @DisplayName("제공자는 하나는 남아야 한다")
  void removeOnlyProvider_rejected() {
    when(router.chain()).thenReturn(List.of(TextProvider.GEMINI));

    assertThatThrownBy(() -> service.removeFromChain(TextProvider.GEMINI, "admin")).isInstanceOf(CustomException.class);
  }
}
