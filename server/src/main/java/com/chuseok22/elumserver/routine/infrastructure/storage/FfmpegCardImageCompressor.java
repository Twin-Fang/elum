package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.media.FfmpegConverter;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * ffmpeg(libwebp) 로 AI 카드 그림 > webp (#1219)
 * 크기는 그대로 (태블릿 화면), 품질 80: 운영 실측 1536×1024 png 1,310KB > 22KB, 약 0.3초
 */
@Component
public class FfmpegCardImageCompressor implements CardImageCompressor {

  static final String WEBP_EXTENSION = "webp";
  // 변환 1장 상한 (실측 약 0.3초)
  static final Duration DEFAULT_TIMEOUT = Duration.ofSeconds(10);
  // webp 품질 80 (눈으로 원본과 차이 없음, #1219)
  private static final List<String> WEBP_OPTIONS = List.of("-c:v", "libwebp", "-quality", "80");

  private final FfmpegConverter ffmpegConverter;

  public FfmpegCardImageCompressor() {
    this(FfmpegConverter.DEFAULT_COMMAND, DEFAULT_TIMEOUT);
  }

  FfmpegCardImageCompressor(String command, Duration timeout) {
    this.ffmpegConverter = new FfmpegConverter(command, timeout);
  }

  @Override
  public Optional<GeneratedImage> toWebp(GeneratedImage image) {
    String extension = image.extension() == null ? "" : image.extension().toLowerCase(Locale.ROOT);
    if (WEBP_EXTENSION.equals(extension)) {
      return Optional.empty();
    }
    return ffmpegConverter.convert(image.bytes(), "." + extension, "." + WEBP_EXTENSION, WEBP_OPTIONS,
        FfmpegCardImageCompressor::isWebp)
      .map(webp -> new GeneratedImage(webp, WEBP_EXTENSION));
  }

  /// WebP 머리 `RIFF....WEBP`
  private static boolean isWebp(byte[] image) {
    return image.length >= 12
      && "RIFF".equals(new String(image, 0, 4, StandardCharsets.US_ASCII))
      && "WEBP".equals(new String(image, 8, 4, StandardCharsets.US_ASCII));
  }
}
