package com.chuseok22.elumserver.routine.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Optional;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * 실제 ffmpeg 로 카드 그림 webp 압축 (#1219). ffmpeg(libwebp)가 없는 곳에서는 변환 시험을 건너뛴다.
 */
class FfmpegCardImageCompressorTest {

  @TempDir
  Path tempDir;

  private final FfmpegCardImageCompressor compressor = new FfmpegCardImageCompressor();

  @Test
  @DisplayName("png 를 더 작은 webp 로 바꾼다")
  void pngToWebp() throws Exception {
    assumeTrue(isWebpEncoderInstalled(), "ffmpeg libwebp 없음");
    byte[] png = drawPng();

    GeneratedImage webp = compressor.toWebp(new GeneratedImage(png, "png")).orElseThrow();

    assertThat(webp.extension()).isEqualTo("webp");
    assertThat(new String(webp.bytes(), 8, 4, StandardCharsets.US_ASCII)).isEqualTo("WEBP");
    assertThat(webp.bytes().length).isLessThan(png.length);
  }

  @Test
  @DisplayName("이미 webp 거나 변환에 실패하면 빈 값 — 저장소가 원본을 그대로 저장")
  void alreadyWebpOrInvalid_isEmpty() {
    assertThat(compressor.toWebp(new GeneratedImage(new byte[]{1}, "webp"))).isEmpty();
    assertThat(compressor.toWebp(new GeneratedImage(new byte[]{1, 2, 3}, "png"))).isEmpty();
    assertThat(new FfmpegCardImageCompressor("elum-no-such-ffmpeg", Duration.ofSeconds(1))
      .toWebp(new GeneratedImage(new byte[]{1}, "png"))).isEmpty();
  }

  @Test
  @DisplayName("저장소는 AI 그림을 webp 열쇠로 저장하고, 옛 png 는 같은 이름의 .webp 사본을 만든다")
  void storage_savesWebpAndCopiesPng() throws Exception {
    byte[] webpBytes = "RIFF0000WEBPVP8 ".getBytes(StandardCharsets.US_ASCII);
    CardImageCompressor fakeCompressor = image -> Optional.of(new GeneratedImage(webpBytes, "webp"));
    LocalFileRoutineImageStorage storage =
      new LocalFileRoutineImageStorage(new RoutineProperties(tempDir.toString()), fakeCompressor);

    assertThat(storage.save("batch-1", 1, new GeneratedImage(new byte[]{1}, "png"))).isEqualTo("batch-1/1.webp");
    assertThat(storage.saveRegenerated("step-1", new GeneratedImage(new byte[]{1}, "png"))).endsWith(".webp");

    Path png = tempDir.resolve("batch-2/1.png");
    Files.createDirectories(png.getParent());
    Files.write(png, new byte[]{1});
    assertThat(storage.saveWebpCopy("batch-2/1.png")).contains("batch-2/1.webp");
    assertThat(tempDir.resolve("batch-2/1.webp")).hasBinaryContent(webpBytes);
    assertThat(png).exists();
    assertThat(storage.saveWebpCopy("batch-2/missing.png")).isEmpty();
  }

  @Test
  @DisplayName("압축에 실패하면 원본 형식 그대로 저장한다 — 그림이 빠지지 않게")
  void storage_compressFails_savesOriginal() {
    LocalFileRoutineImageStorage storage =
      new LocalFileRoutineImageStorage(new RoutineProperties(tempDir.toString()), image -> Optional.empty());

    assertThat(storage.save("batch-1", 1, new GeneratedImage(new byte[]{1}, "png"))).isEqualTo("batch-1/1.png");
  }

  private static boolean isWebpEncoderInstalled() {
    try {
      Process process = new ProcessBuilder("ffmpeg", "-hide_banner", "-encoders").redirectErrorStream(true).start();
      String encoders = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
      return process.waitFor() == 0 && encoders.contains("libwebp");
    } catch (Exception e) {
      return false;
    }
  }

  /// 단색 면과 선이 있는 그림 (AI 카드 그림처럼 단순한 그림)
  private static byte[] drawPng() throws Exception {
    BufferedImage image = new BufferedImage(600, 400, BufferedImage.TYPE_INT_RGB);
    Graphics2D graphics = image.createGraphics();
    graphics.setColor(Color.WHITE);
    graphics.fillRect(0, 0, 600, 400);
    graphics.setColor(new Color(0xF5, 0xEE, 0xE3));
    graphics.fillOval(100, 80, 240, 240);
    graphics.setColor(Color.DARK_GRAY);
    graphics.drawOval(100, 80, 240, 240);
    graphics.dispose();
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    ImageIO.write(image, "png", out);
    return out.toByteArray();
  }
}
