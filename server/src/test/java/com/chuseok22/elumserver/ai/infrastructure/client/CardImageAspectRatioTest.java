package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 카드 그림 칸 비율 (이슈 #460).
 *
 * <p>Figma 카드의 그림 칸은 313×230(1.361:1)이고 앱이 {@code BoxFit.cover} 로 채운다. 생성 비율이 칸과
 * 멀수록 그만큼 잘린다. 제공자 상수를 아무 생각 없이 되돌리면 정사각 1024x1024(위·아래 26.5% 잘림)로 돌아가므로
 * 잘림 비율의 상한을 못박는다.
 */
class CardImageAspectRatioTest {

  private static final double FIGMA_CARD_IMAGE_RATIO = 313.0 / 230.0;

  /** 칸에 cover 로 채울 때 버려지는 비율 (0~1). */
  private static double croppedFraction(double imageRatio) {
    return imageRatio >= FIGMA_CARD_IMAGE_RATIO
      ? 1.0 - FIGMA_CARD_IMAGE_RATIO / imageRatio   // 좌·우가 잘림
      : 1.0 - imageRatio / FIGMA_CARD_IMAGE_RATIO;  // 위·아래가 잘림
  }

  @Test
  @DisplayName("OpenAI 크기는 가로형이다 — 정사각(위·아래 26.5% 잘림)으로 돌아가지 않는다")
  void openAi_sizeIsLandscape() {
    String[] size = OpenAiImageClient.IMAGE_SIZE.split("x");
    double ratio = Double.parseDouble(size[0]) / Double.parseDouble(size[1]);

    assertThat(OpenAiImageClient.IMAGE_SIZE).isEqualTo("1536x1024");
    assertThat(croppedFraction(ratio)).isLessThan(0.10);
  }

  @Test
  @DisplayName("FLUX 크기는 칸 비율에 0.5% 안으로 맞고 1MP 를 넘지 않는다")
  void flux_sizeMatchesCard() {
    double ratio = (double) FluxImageClient.IMAGE_WIDTH / FluxImageClient.IMAGE_HEIGHT;

    assertThat(croppedFraction(ratio)).isLessThan(0.005);
    assertThat((long) FluxImageClient.IMAGE_WIDTH * FluxImageClient.IMAGE_HEIGHT).isLessThanOrEqualTo(1024L * 1024L);
  }
}
