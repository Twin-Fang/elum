package com.chuseok22.elumserver.talk.infrastructure.image;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.routine.core.RoutinePhotoProcessor;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TalkImageBlurrerTest {

  private final TalkImageBlurrer talkImageBlurrer = new TalkImageBlurrer(new RoutinePhotoProcessor());

  @Test
  @DisplayName("흐리게 하면 크기는 그대로고 인접 픽셀 차이는 원본의 1/4 미만이다")
  void blur_changesPixels_keepsSize() throws Exception {
    BufferedImage checkerboard = new BufferedImage(64, 64, BufferedImage.TYPE_INT_RGB);
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        checkerboard.setRGB(x, y, (x + y) % 2 == 0 ? 0xFFFFFF : 0x000000);
      }
    }
    ByteArrayOutputStream pngBytes = new ByteArrayOutputStream();
    ImageIO.write(checkerboard, "png", pngBytes);

    byte[] blurredBytes = talkImageBlurrer.blur(pngBytes.toByteArray());
    BufferedImage blurred = ImageIO.read(new ByteArrayInputStream(blurredBytes));

    assertThat(blurred.getWidth()).isEqualTo(64);
    assertThat(blurred.getHeight()).isEqualTo(64);
    assertThat(averageNeighborDifference(blurred)).isLessThan(averageNeighborDifference(checkerboard) / 4);
  }

  @Test
  @DisplayName("그림이 아닌 바이트는 형식 오류로 거절한다")
  void blur_invalidBytes_throwsInvalidType() {
    assertThatThrownBy(() -> talkImageBlurrer.blur(new byte[]{1, 2, 3}))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE));
  }

  /** 가로로 이웃한 픽셀의 밝기 차이 평균 */
  private static double averageNeighborDifference(BufferedImage image) {
    long totalDifference = 0;
    long pairCount = 0;
    for (int y = 0; y < image.getHeight(); y++) {
      for (int x = 0; x + 1 < image.getWidth(); x++) {
        totalDifference += Math.abs(brightnessOf(image.getRGB(x, y)) - brightnessOf(image.getRGB(x + 1, y)));
        pairCount++;
      }
    }
    return (double) totalDifference / pairCount;
  }

  private static int brightnessOf(int rgb) {
    return (((rgb >> 16) & 0xFF) + ((rgb >> 8) & 0xFF) + (rgb & 0xFF)) / 3;
  }
}
