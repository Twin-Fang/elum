package com.chuseok22.elumserver.routine.core;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 카드 사진 재가공 (이슈 #455).
 *
 * <p>사진은 {@code javax.imageio} 로 그 자리에서 만들어 쓴다 — 파일 픽스처를 두지 않는다.
 */
class RoutinePhotoProcessorTest {

  private final RoutinePhotoProcessor processor = new RoutinePhotoProcessor();

  // ── 형식 ────────────────────────────────────────────

  @Test
  @DisplayName("JPEG 는 통과하고 결과도 JPEG 다")
  void jpeg_passes() throws IOException {
    byte[] out = processor.process(encode(solid(100, 80, Color.RED), "jpeg"));

    assertThat(isJpeg(out)).isTrue();
    assertThat(decode(out).getWidth()).isEqualTo(100);
  }

  @Test
  @DisplayName("PNG 는 통과하고 결과는 JPEG 로 바뀐다")
  void png_becomesJpeg() throws IOException {
    byte[] out = processor.process(encode(solid(100, 80, Color.BLUE), "png"));

    assertThat(isJpeg(out)).isTrue();
  }

  @Test
  @DisplayName("WebP·GIF·텍스트·빈 파일·null 은 형식 오류로 거절한다")
  void otherTypes_rejected() throws IOException {
    byte[] webp = "RIFF\0\0\0\0WEBPVP8 ".getBytes(StandardCharsets.ISO_8859_1);
    byte[] gif = encode(solid(10, 10, Color.GREEN), "gif");

    for (byte[] bad : new byte[][]{webp, gif, "안녕하세요 hello".getBytes(StandardCharsets.UTF_8), new byte[0], null}) {
      assertInvalidType(bad);
    }
  }

  @Test
  @DisplayName("확장자만 바꾼 게 아니라 서명으로 가린다 — 이미지 서명이 없으면 내용이 무엇이든 거절")
  void signatureNotName() {
    assertInvalidType("<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>"
      .getBytes(StandardCharsets.UTF_8));
  }

  @Test
  @DisplayName("깨진 JPEG·PNG 는 형식 오류로 거절한다")
  void broken_rejected() throws IOException {
    byte[] jpeg = encode(solid(200, 200, Color.RED), "jpeg");
    byte[] truncatedJpeg = java.util.Arrays.copyOf(jpeg, 40);
    byte[] garbageJpeg = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 1, 2, 3, 4, 5, 6, 7, 8};
    byte[] pngHead = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0};

    assertInvalidType(truncatedJpeg);
    assertInvalidType(garbageJpeg);
    assertInvalidType(pngHead);
  }

  // ── 크기 ────────────────────────────────────────────

  @Test
  @DisplayName("긴 변이 1024 를 넘으면 1024 로 줄인다 — 비율은 유지한다")
  void large_isScaledDown() throws IOException {
    BufferedImage out = decode(processor.process(encode(solid(3000, 2000, Color.ORANGE), "jpeg")));

    assertThat(out.getWidth()).isEqualTo(1024);
    assertThat(out.getHeight()).isBetween(682, 684);
  }

  @Test
  @DisplayName("아주 큰 사진(읽으며 솎아 내는 경로)도 1024 로 줄어든다")
  void veryLarge_isScaledDown() throws IOException {
    BufferedImage gray = new BufferedImage(6000, 4000, BufferedImage.TYPE_BYTE_GRAY);
    BufferedImage out = decode(processor.process(encode(gray, "jpeg")));

    assertThat(Math.max(out.getWidth(), out.getHeight())).isEqualTo(1024);
  }

  @Test
  @DisplayName("작은 사진은 늘리지 않고 그대로 둔다")
  void small_isKept() throws IOException {
    BufferedImage out = decode(processor.process(encode(solid(200, 100, Color.PINK), "png")));

    assertThat(out.getWidth()).isEqualTo(200);
    assertThat(out.getHeight()).isEqualTo(100);
  }

  @Test
  @DisplayName("픽셀 폭탄 — 긴 변이 8000 을 넘으면 디코드 전에 거절한다")
  void pixelBomb_sideLimit() throws IOException {
    byte[] png = encode(new BufferedImage(8001, 10, BufferedImage.TYPE_BYTE_BINARY), "png");

    assertTooLarge(png);
  }

  @Test
  @DisplayName("픽셀 폭탄 — 총 픽셀이 4천만을 넘으면 거절한다")
  void pixelBomb_totalLimit() throws IOException {
    // 7000x6000 = 4200만. 한 색이라 PNG 는 수 KB 라 파일 크기 검사로는 못 잡는다.
    byte[] png = encode(new BufferedImage(7000, 6000, BufferedImage.TYPE_BYTE_BINARY), "png");

    assertThat(png.length).isLessThan(RoutinePhotoProcessor.MAX_BYTES);
    assertTooLarge(png);
  }

  // ── 알파 ────────────────────────────────────────────

  @Test
  @DisplayName("투명한 PNG 는 흰 배경에 합성한다 — 검게 나오지 않는다")
  void alpha_compositedOnWhite() throws IOException {
    BufferedImage transparent = new BufferedImage(50, 50, BufferedImage.TYPE_INT_ARGB);

    BufferedImage out = decode(processor.process(encode(transparent, "png")));

    Color pixel = new Color(out.getRGB(25, 25));
    assertThat(pixel.getRed()).isGreaterThan(245);
    assertThat(pixel.getGreen()).isGreaterThan(245);
    assertThat(pixel.getBlue()).isGreaterThan(245);
  }

  // ── 메타데이터 ───────────────────────────────────────

  @Test
  @DisplayName("결과에 EXIF(APP1) 가 남지 않는다 — 촬영 위치가 저장되면 안 된다")
  void exif_isStripped() throws IOException {
    byte[] withExif = injectExif(encode(solid(64, 64, Color.RED), "jpeg"), 1, false,
      "GPS-SECRET-LOCATION".getBytes(StandardCharsets.US_ASCII));
    assertThat(hasApp1(withExif)).as("전제: 입력에는 EXIF 가 있다").isTrue();

    byte[] out = processor.process(withExif);

    assertThat(hasApp1(out)).isFalse();
    assertThat(new String(out, StandardCharsets.ISO_8859_1)).doesNotContain("GPS-SECRET-LOCATION");
  }

  // ── EXIF 방향 ───────────────────────────────────────

  @Test
  @DisplayName("EXIF 방향 6(시계 90도) — 가로 사진이 세로로 서고 왼쪽 위 색이 오른쪽 위로 간다")
  void orientation6_rotatesClockwise() throws IOException {
    byte[] jpeg = injectExif(quadrants(), 6, false, null);

    BufferedImage out = decode(processor.process(jpeg));

    assertThat(out.getWidth()).isEqualTo(40);
    assertThat(out.getHeight()).isEqualTo(80);
    // 원본 왼쪽 위(빨강)는 시계 방향으로 돌면 오른쪽 위에 온다
    assertDominant(out, 30, 10, Color.RED);
  }

  @Test
  @DisplayName("EXIF 방향 8(반시계 90도) — 왼쪽 위 색이 왼쪽 아래로 간다")
  void orientation8_rotatesCounterClockwise() throws IOException {
    BufferedImage out = decode(processor.process(injectExif(quadrants(), 8, false, null)));

    assertThat(out.getWidth()).isEqualTo(40);
    assertThat(out.getHeight()).isEqualTo(80);
    assertDominant(out, 10, 70, Color.RED);
  }

  @Test
  @DisplayName("EXIF 방향 3(180도) — 왼쪽 위 색이 오른쪽 아래로 간다 (리틀 엔디언도 읽는다)")
  void orientation3_littleEndian() throws IOException {
    BufferedImage out = decode(processor.process(injectExif(quadrants(), 3, true, null)));

    assertThat(out.getWidth()).isEqualTo(80);
    assertDominant(out, 70, 30, Color.RED);
  }

  @Test
  @DisplayName("EXIF 방향 2(좌우 반전) — 왼쪽 위 색이 오른쪽 위로 간다")
  void orientation2_mirrors() throws IOException {
    BufferedImage out = decode(processor.process(injectExif(quadrants(), 2, false, null)));

    assertDominant(out, 70, 10, Color.RED);
  }

  @Test
  @DisplayName("EXIF 방향이 없으면 그대로 둔다")
  void noExif_keepsOrientation() throws IOException {
    BufferedImage out = decode(processor.process(quadrants()));

    assertThat(out.getWidth()).isEqualTo(80);
    assertDominant(out, 10, 10, Color.RED);
  }

  @Test
  @DisplayName("방향 파서 — 1~8 을 빅·리틀 엔디언 모두 읽고, 범위 밖·깨진 값은 1 로 돌린다")
  void orientationParser() throws IOException {
    byte[] base = encode(solid(8, 8, Color.RED), "jpeg");
    for (int value = 1; value <= 8; value++) {
      assertThat(RoutinePhotoProcessor.readExifOrientation(injectExif(base, value, false, null))).isEqualTo(value);
      assertThat(RoutinePhotoProcessor.readExifOrientation(injectExif(base, value, true, null))).isEqualTo(value);
    }
    assertThat(RoutinePhotoProcessor.readExifOrientation(injectExif(base, 9, false, null))).isEqualTo(1);
    assertThat(RoutinePhotoProcessor.readExifOrientation(injectExif(base, 0, true, null))).isEqualTo(1);
    assertThat(RoutinePhotoProcessor.readExifOrientation(base)).isEqualTo(1);
    // 세그먼트 길이가 파일 밖을 가리키는 깨진 APP1
    byte[] broken = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE1, (byte) 0xFF, (byte) 0xFF, 'E', 'x'};
    assertThat(RoutinePhotoProcessor.readExifOrientation(broken)).isEqualTo(1);
    assertThat(RoutinePhotoProcessor.readExifOrientation(new byte[]{(byte) 0xFF, (byte) 0xD8})).isEqualTo(1);
  }

  // ── 도움 ────────────────────────────────────────────

  private void assertInvalidType(byte[] bytes) {
    assertThatThrownBy(() -> processor.process(bytes))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE));
  }

  private void assertTooLarge(byte[] bytes) {
    assertThatThrownBy(() -> processor.process(bytes))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE));
  }

  /** 픽셀 색이 기대한 색에 가까운지(JPEG 손실 허용). */
  private void assertDominant(BufferedImage image, int x, int y, Color expected) {
    Color actual = new Color(image.getRGB(x, y));
    assertThat(Math.abs(actual.getRed() - expected.getRed())).as("R @%d,%d", x, y).isLessThan(60);
    assertThat(Math.abs(actual.getGreen() - expected.getGreen())).as("G @%d,%d", x, y).isLessThan(60);
    assertThat(Math.abs(actual.getBlue() - expected.getBlue())).as("B @%d,%d", x, y).isLessThan(60);
  }

  /** 80x40 — 왼쪽 위 빨강, 오른쪽 위 초록, 왼쪽 아래 파랑, 오른쪽 아래 검정. 방향을 눈으로 가리는 시험지. */
  private byte[] quadrants() throws IOException {
    BufferedImage image = new BufferedImage(80, 40, BufferedImage.TYPE_INT_RGB);
    Graphics2D g = image.createGraphics();
    g.setColor(Color.RED);
    g.fillRect(0, 0, 40, 20);
    g.setColor(Color.GREEN);
    g.fillRect(40, 0, 40, 20);
    g.setColor(Color.BLUE);
    g.fillRect(0, 20, 40, 20);
    g.setColor(Color.BLACK);
    g.fillRect(40, 20, 40, 20);
    g.dispose();
    return encode(image, "jpeg");
  }

  private BufferedImage solid(int w, int h, Color color) {
    BufferedImage image = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
    Graphics2D g = image.createGraphics();
    g.setColor(color);
    g.fillRect(0, 0, w, h);
    g.dispose();
    return image;
  }

  private byte[] encode(BufferedImage image, String format) throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    ImageIO.write(image, format, out);
    return out.toByteArray();
  }

  private BufferedImage decode(byte[] bytes) throws IOException {
    return ImageIO.read(new ByteArrayInputStream(bytes));
  }

  private boolean isJpeg(byte[] b) {
    return (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8;
  }

  /** SOI 뒤에서 이미지 데이터(SOS) 전까지 APP1 이 있는지 본다. */
  private boolean hasApp1(byte[] jpeg) {
    int pos = 2;
    while (pos + 4 <= jpeg.length && (jpeg[pos] & 0xFF) == 0xFF) {
      int marker = jpeg[pos + 1] & 0xFF;
      if (marker == 0xDA) {
        return false;
      }
      if (marker == 0xE1) {
        return true;
      }
      pos += 2 + (((jpeg[pos + 2] & 0xFF) << 8) | (jpeg[pos + 3] & 0xFF));
    }
    return false;
  }

  /** SOI 바로 뒤에 방향 값을 담은 EXIF APP1 을 끼운다. extra 는 IFD 뒤에 붙이는 표식 바이트(위치 정보 흉내). */
  private byte[] injectExif(byte[] jpeg, int orientation, boolean little, byte[] extra) {
    ByteArrayOutputStream tiff = new ByteArrayOutputStream();
    tiff.writeBytes(little ? new byte[]{'I', 'I'} : new byte[]{'M', 'M'});
    writeU16(tiff, 42, little);
    writeU32(tiff, 8, little);
    writeU16(tiff, 1, little); // 항목 1개
    writeU16(tiff, 0x0112, little);
    writeU16(tiff, 3, little); // SHORT
    writeU32(tiff, 1, little);
    writeU16(tiff, orientation, little);
    writeU16(tiff, 0, little);
    writeU32(tiff, 0, little); // 다음 IFD 없음
    if (extra != null) {
      tiff.writeBytes(extra);
    }
    byte[] tiffBytes = tiff.toByteArray();

    ByteArrayOutputStream app1 = new ByteArrayOutputStream();
    app1.writeBytes(new byte[]{(byte) 0xFF, (byte) 0xE1});
    writeU16(app1, 2 + 6 + tiffBytes.length, false);
    app1.writeBytes(new byte[]{'E', 'x', 'i', 'f', 0, 0});
    app1.writeBytes(tiffBytes);

    ByteArrayOutputStream out = new ByteArrayOutputStream();
    out.writeBytes(new byte[]{jpeg[0], jpeg[1]});
    out.writeBytes(app1.toByteArray());
    out.write(jpeg, 2, jpeg.length - 2);
    return out.toByteArray();
  }

  private void writeU16(ByteArrayOutputStream out, int value, boolean little) {
    if (little) {
      out.write(value & 0xFF);
      out.write((value >> 8) & 0xFF);
    } else {
      out.write((value >> 8) & 0xFF);
      out.write(value & 0xFF);
    }
  }

  private void writeU32(ByteArrayOutputStream out, int value, boolean little) {
    if (little) {
      writeU16(out, value & 0xFFFF, true);
      writeU16(out, (value >> 16) & 0xFFFF, true);
    } else {
      writeU16(out, (value >> 16) & 0xFFFF, false);
      writeU16(out, value & 0xFFFF, false);
    }
  }
}
