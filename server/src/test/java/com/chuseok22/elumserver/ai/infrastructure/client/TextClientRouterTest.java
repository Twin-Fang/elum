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

  @Mock
  private TextGenerationClient claudeClient;

  private TextClientRouter router() {
    lenient().when(geminiClient.provider()).thenReturn(TextProvider.GEMINI);
    lenient().when(openAiClient.provider()).thenReturn(TextProvider.OPENAI);
    lenient().when(claudeClient.provider()).thenReturn(TextProvider.CLAUDE);
    return new TextClientRouter(List.of(geminiClient, openAiClient, claudeClient), systemConfigService);
  }

  private void fallbacks(String value) {
    when(systemConfigService.getString(ConfigKey.TEXT_PROVIDER_FALLBACKS)).thenReturn(value);
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

  @Test
  @DisplayName("대체 순서가 비어 있으면 고른 제공자 그대로 — 배포만으로 운영 동작이 바뀌지 않는다 (#1083)")
  void emptyFallbacks_returnsSelectedClientItself() {
    TextClientRouter router = router();
    selected("GEMINI");
    fallbacks("");
    when(geminiClient.available()).thenReturn(true);

    assertThat(router.current()).isSameAs(geminiClient);
    assertThat(router.chain()).containsExactly(TextProvider.GEMINI);
  }

  @Test
  @DisplayName("Claude 를 고를 수 있고, 대체 순서는 첫 제공자 뒤에 중복 없이 붙는다")
  void chain_selectedFirstThenFallbacksWithoutDuplicates() {
    TextClientRouter router = router();
    selected("CLAUDE");
    fallbacks("gemini,CLAUDE,OPENAI,NOT_A_PROVIDER");

    assertThat(router.chain()).containsExactly(TextProvider.CLAUDE, TextProvider.GEMINI, TextProvider.OPENAI);
  }

  @Test
  @DisplayName("키 없는 제공자는 사슬에서 건너뛰고, 하나만 남으면 그 제공자 그대로 쓴다")
  void unavailableStepSkipped() {
    TextClientRouter router = router();
    selected("CLAUDE");
    fallbacks("GEMINI");
    when(claudeClient.available()).thenReturn(false);
    when(geminiClient.available()).thenReturn(true);

    assertThat(router.current()).isSameAs(geminiClient);
  }

  @Test
  @DisplayName("쓸 수 있는 제공자가 둘 이상이면 실패 시 넘기는 묶음을 준다 — 1번이 실패하면 2번 결과가 나간다")
  void multipleUsableSteps_fallsBackOnFailure() {
    TextClientRouter router = router();
    selected("CLAUDE");
    fallbacks("GEMINI");
    when(claudeClient.available()).thenReturn(true);
    when(geminiClient.available()).thenReturn(true);
    when(claudeClient.pickPictogramJson("t", "d")).thenThrow(new IllegalStateException("429"));
    when(geminiClient.pickPictogramJson("t", "d")).thenReturn("{\"pictogramId\":\"toothbrush\"}");

    TextGenerationClient current = router.current();

    assertThat(current.provider()).isEqualTo(TextProvider.CLAUDE);
    assertThat(current.pickPictogramJson("t", "d")).isEqualTo("{\"pictogramId\":\"toothbrush\"}");
  }

  @Test
  @DisplayName("사슬 전부 키가 없으면 TEXT_PROVIDER_UNAVAILABLE")
  void allStepsUnavailable_throws() {
    TextClientRouter router = router();
    selected("CLAUDE");
    fallbacks("OPENAI");
    when(claudeClient.available()).thenReturn(false);
    when(openAiClient.available()).thenReturn(false);

    assertThatThrownBy(router::current)
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.TEXT_PROVIDER_UNAVAILABLE);
  }
}
