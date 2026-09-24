package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 실제 fal 을 부르지 않는다. 보내는 본문만 본다 — 크기·단계·seed 가 곧 돈과 품질이다.
class FluxImageClientTest {

  private final FluxImageClient client = new FluxImageClient(
    mock(PromptTemplateService.class), new FluxPromptBuilder(),
    mock(SystemConfigService.class), mock(AiCallLogService.class));

  @Test
  @DisplayName("1024×864 · 4 steps · 한 장 — fal 은 1MP 미만도 1MP 로 받으니 1MP 안에서 카드 비율(1.19:1)로 크게")
  void body_sizeStepsCount() {
    Map<String, Object> body = client.requestBody("prompt", 12345);

    assertThat(body.get("image_size")).isEqualTo(Map.of("width", 1024, "height", 864));
    assertThat(body.get("num_inference_steps")).isEqualTo(4);
    assertThat(body.get("num_images")).isEqualTo(1);
    assertThat(body.get("prompt")).isEqualTo("prompt");
    assertThat(body.get("seed")).isEqualTo(12345);
    // 1024×864 = 0.88MP — 1MP 를 넘으면 2MP 로 청구된다.
    assertThat(1024 * 864).isLessThanOrEqualTo(1024 * 1024);
  }

  @Test
  @DisplayName("seed 가 없으면 싣지 않는다")
  void body_noSeed() {
    assertThat(client.requestBody("prompt", null)).doesNotContainKey("seed");
  }

  @Test
  @DisplayName("한국어 카드 설명으로 바로 부르면 거절한다 — 영어 장면 없이 부르면 사람을 그린다(#373 1차)")
  void koreanDescriptionDirectly_isRejected() {
    assertThatThrownBy(() -> client.generateImage("옷을 입어요", CharacterType.LULU))
      .isInstanceOf(IllegalStateException.class);
  }
}
