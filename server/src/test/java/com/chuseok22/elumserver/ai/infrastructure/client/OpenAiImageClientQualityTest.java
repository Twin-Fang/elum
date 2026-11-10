package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * OpenAI 그림 품질 고르기: 관리자 설정 OPENAI_IMAGE_QUALITY 하나만 따름
 */
class OpenAiImageClientQualityTest {

  private final SystemConfigService systemConfigService = mock(SystemConfigService.class);
  private final OpenAiImageClient client = new OpenAiImageClient(null, null, systemConfigService,
    mock(AiCallLogService.class), mock(AiRestClientFactory.class));

  @Test
  @DisplayName("그림 품질은 관리자가 고른 OPENAI_IMAGE_QUALITY 값 그대로다 — 회원 권한으로 갈리지 않는다")
  void usesConfiguredQuality() {
    when(systemConfigService.getString(ConfigKey.OPENAI_IMAGE_QUALITY)).thenReturn("medium");

    assertThat(client.resolveQuality()).isEqualTo("medium");
  }

  @Test
  @DisplayName("배포만으로 그림 품질·원가가 바뀌지 않는다 — 기본 품질 low, 모델 gpt-image-1-mini")
  void defaultsKeepCurrentImageCost() {
    assertThat(ConfigKey.OPENAI_IMAGE_QUALITY.getDefaultValue()).isEqualTo("low");
    assertThat(ConfigKey.OPENAI_IMAGE_MODEL.getDefaultValue()).isEqualTo("gpt-image-1-mini");
  }
}
