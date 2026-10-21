package com.chuseok22.elumserver.talk.infrastructure.image;

import com.chuseok22.elumserver.routine.core.RoutinePhotoProcessor;
import java.awt.image.BufferedImage;
import java.util.Arrays;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 이야기 그림 흐리기: 보호자 사진 > 긴 변 1024 축소 > 박스 블러 3회 > JPEG
 * 사진 속 얼굴·글자를 알아볼 수 없게 하는 용도라 가장자리는 바깥 픽셀 복제로 채움
 */
@Component
@RequiredArgsConstructor
public class TalkImageBlurrer {

  // 블러 반경: 긴 변의 4%, 최소 12px
  private static final double BLUR_RADIUS_RATIO = 0.04;
  private static final int MINIMUM_BLUR_RADIUS_PIXELS = 12;
  private static final int BOX_BLUR_PASS_COUNT = 3;

  private final RoutinePhotoProcessor routinePhotoProcessor;

  /**
   * @param jpegOrPng 보호자 사진 바이트
   * @return 흐려진 JPEG 바이트
   * @throws com.chuseok22.elumserver.common.infrastructure.exception.CustomException 형식이 아니면
   *         {@code ROUTINE_STEP_IMAGE_INVALID_TYPE}
   */
  public byte[] blur(byte[] jpegOrPng) {
    // 검증·축소·방향 보정은 카드 사진 처리와 같은 규칙
    BufferedImage image = routinePhotoProcessor.processToImage(jpegOrPng);
    int width = image.getWidth();
    int height = image.getHeight();
    int radius = Math.max(MINIMUM_BLUR_RADIUS_PIXELS, (int) Math.round(Math.max(width, height) * BLUR_RADIUS_RATIO));

    int[] pixels = image.getRGB(0, 0, width, height, null, 0, width);
    int[] red = channelOf(pixels, 16);
    int[] green = channelOf(pixels, 8);
    int[] blue = channelOf(pixels, 0);
    for (int pass = 0; pass < BOX_BLUR_PASS_COUNT; pass++) {
      boxBlur(red, width, height, radius);
      boxBlur(green, width, height, radius);
      boxBlur(blue, width, height, radius);
    }

    BufferedImage blurred = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
    for (int index = 0; index < pixels.length; index++) {
      pixels[index] = (red[index] << 16) | (green[index] << 8) | blue[index];
    }
    blurred.setRGB(0, 0, width, height, pixels, 0, width);
    return routinePhotoProcessor.encodeJpeg(blurred);
  }

  private static int[] channelOf(int[] pixels, int shift) {
    int[] channel = new int[pixels.length];
    for (int index = 0; index < pixels.length; index++) {
      channel[index] = (pixels[index] >> shift) & 0xFF;
    }
    return channel;
  }

  // 가로 > 세로 순서로 한 번씩
  private static void boxBlur(int[] channel, int width, int height, int radius) {
    int[] line = new int[Math.max(width, height)];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        line[x] = channel[y * width + x];
      }
      blurLine(line, width, radius);
      for (int x = 0; x < width; x++) {
        channel[y * width + x] = line[x];
      }
    }
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        line[y] = channel[y * width + x];
      }
      blurLine(line, height, radius);
      for (int y = 0; y < height; y++) {
        channel[y * width + x] = line[y];
      }
    }
  }

  // 한 줄 이동 평균 (창 크기 2r+1, 범위 밖은 끝 픽셀로 채움)
  private static void blurLine(int[] line, int length, int radius) {
    int[] source = Arrays.copyOf(line, length);
    int windowSize = 2 * radius + 1;
    long windowSum = 0;
    for (int offset = -radius; offset <= radius; offset++) {
      windowSum += source[clamp(offset, length)];
    }
    for (int index = 0; index < length; index++) {
      line[index] = (int) ((windowSum + windowSize / 2) / windowSize);
      windowSum += source[clamp(index + radius + 1, length)] - source[clamp(index - radius, length)];
    }
  }

  private static int clamp(int index, int length) {
    return Math.min(length - 1, Math.max(0, index));
  }
}
