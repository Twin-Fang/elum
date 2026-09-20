package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class TextClientRouterTest {

  @Mock
  private SystemConfigService systemConfigService;

  @Mock
  private TextGenerationClient geminiClient;

  @Mock
  private TextGenerationClient openAiClient;

  private TextClientRouter router() {
    lenient().when(geminiClient.provider()).thenReturn(TextProvider.GEMINI);
    lenient().when(openAiClient.provider()).thenReturn(TextProvider.OPENAI);
    return new TextClientRouter(List.of(geminiClient, openAiClient), systemConfigService);
  }

  private void selected(String value) {
    when(systemConfigService.getString(ConfigKey.TEXT_PROVIDER_SELECTED)).thenReturn(value);
  }

  @Test
  @DisplayName("설정에 적힌 제공자를 돌려준다")
  void picksSelectedProvider() {
    TextClientRouter router = router();
    selected("OPENAI");
    when(openAiClient.available()).thenReturn(true);

    assertThat(router.current()).isSameAs(openAiClient);
  }

  @Test
  @DisplayName("키가 없는 제공자를 골라두면 생성을 거부한다 — 일과 생성이 전부 실패하게 두지 않는다")
  void unavailableProvider_throws() {
    TextClientRouter router = router();
    selected("OPENAI");
    when(openAiClient.available()).thenReturn(false);

    assertThatThrownBy(router::current)
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.TEXT_PROVIDER_UNAVAILABLE);
  }

  @Test
  @DisplayName("설정값이 망가져 있어도 기본 제공자로 떨어진다 — 설정 하나로 멈추지 않는다")
  void brokenSetting_fallsBackToGemini() {
    TextClientRouter router = router();
    selected("NOT_A_PROVIDER");

    assertThat(router.selected()).isEqualTo(TextProvider.GEMINI);
  }

  @Test
  @DisplayName("설정값 앞뒤 공백은 무시한다")
  void trimsSelectedValue() {
    TextClientRouter router = router();
    selected("  OPENAI  ");

    assertThat(router.selected()).isEqualTo(TextProvider.OPENAI);
  }
}
