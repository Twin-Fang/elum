package com.chuseok22.elumserver.common.infrastructure.media;

import java.time.Duration;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * 링크 미리보기용 그림 변환 (#1219): webp > JPEG (카카오톡 미리보기가 webp 를 못 그림)
 * 실패면 빈 값 (호출부가 기본 그림으로 대신)
 */
@Component
public class PreviewImageConverter {

  // 변환 1장 상한
  private static final Duration TIMEOUT = Duration.ofSeconds(10);
  // 가로 1200 이하로 줄임(미리보기 권장 크기), JPEG 품질 단계 3 (2 최고 ~ 31 최저)
  private static final List<String> JPEG_OPTIONS =
    List.of("-vf", "scale='min(1200,iw)':-2", "-q:v", "3");

  private final FfmpegConverter ffmpegConverter = new FfmpegConverter(FfmpegConverter.DEFAULT_COMMAND, TIMEOUT);

  /**
   * webp 바이트 > JPEG 바이트. 실패면 빈 값
   */
  public Optional<byte[]> webpToJpeg(byte[] webp) {
    return ffmpegConverter.convert(webp, ".webp", ".jpg", JPEG_OPTIONS, PreviewImageConverter::isJpeg);
  }

  /// JPEG 머리 FF D8 FF
  private static boolean isJpeg(byte[] image) {
    return image.length >= 3 && (image[0] & 0xFF) == 0xFF && (image[1] & 0xFF) == 0xD8 && (image[2] & 0xFF) == 0xFF;
  }
}
