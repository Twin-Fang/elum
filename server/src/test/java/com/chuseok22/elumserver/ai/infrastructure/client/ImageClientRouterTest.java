package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.ImageProvider;
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
class ImageClientRouterTest {

  @Mock
  private SystemConfigService systemConfigService;

  @Mock
  private ImageGenerationClient geminiClient;

  @Mock
  private ImageGenerationClient openAiClient;

  private ImageClientRouter router() {
    lenient().when(geminiClient.provider()).thenReturn(ImageProvider.GEMINI);
    lenient().when(openAiClient.provider()).thenReturn(ImageProvider.OPENAI);
    return new ImageClientRouter(List.of(geminiClient, openAiClient), systemConfigService);
  }

  private void selected(String value) {
    when(systemConfigService.getString(ConfigKey.IMAGE_PROVIDER_SELECTED)).thenReturn(value);
  }

  @Test
  @DisplayName("설정에 적힌 제공자를 돌려준다")
  void picksSelectedProvider() {
    ImageClientRouter router = router();
    selected("OPENAI");
    when(openAiClient.available()).thenReturn(true);

    assertThat(router.current()).isSameAs(openAiClient);
  }

  @Test
  @DisplayName("키가 없는 제공자를 골라두면 생성을 거부한다 — 전부 실패하게 두지 않는다")
  void unavailableProvider_throws() {
    ImageClientRouter router = router();
    selected("OPENAI");
    when(openAiClient.available()).thenReturn(false);

    assertThatThrownBy(router::current)
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.IMAGE_PROVIDER_UNAVAILABLE));
  }

  @Test
  @DisplayName("설정값이 알 수 없는 이름이면 기본 제공자로 떨어진다")
  void unknownValue_fallsBackToGemini() {
    ImageClientRouter router = router();
    selected("없는제공자");
    when(geminiClient.available()).thenReturn(true);

    assertThat(router.selected()).isEqualTo(ImageProvider.GEMINI);
    assertThat(router.current()).isSameAs(geminiClient);
  }

  @Test
  @DisplayName("설정값 앞뒤 공백을 무시한다")
  void trimsSelectedValue() {
    ImageClientRouter router = router();
    selected("  OPENAI  ");

    assertThat(router.selected()).isEqualTo(ImageProvider.OPENAI);
  }

  @Test
  @DisplayName("구현체가 없는 제공자를 골라도 예외로 끝난다")
  void providerWithoutImplementation_throws() {
    ImageClientRouter router = router();
    selected("FLUX");

    assertThat(router.of(ImageProvider.FLUX)).isEmpty();
    assertThatThrownBy(router::current).isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("등록된 제공자를 모두 나열한다 — 관리자 화면이 상태를 보여줄 때 쓴다")
  void listsAllClients() {
    assertThat(router().all()).containsExactly(geminiClient, openAiClient);
  }
}
