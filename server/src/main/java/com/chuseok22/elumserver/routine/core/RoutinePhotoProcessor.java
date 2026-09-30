package com.chuseok22.elumserver.routine.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.Locale;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReadParam;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.MemoryCacheImageOutputStream;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 보호자가 올린 카드 사진을 앱이 쓰기 좋게 다시 만든다 (이슈 #455).
 *
 * <p>새 의존성 없이 {@code javax.imageio} 만 쓴다. 처리 순서:
 * <ol>
 *   <li><b>서명으로 형식을 가린다</b> — JPEG·PNG 만. Content-Type 과 파일 이름은 믿지 않는다.</li>
 *   <li><b>디코드 전에 크기를 잰다</b> — 작은 파일이 수억 픽셀로 풀리는 "픽셀 폭탄"이 힙을 터뜨리지 않게.</li>
 *   <li>긴 변을 {@value #OUTPUT_MAX_SIDE}px 로 줄이고(작으면 그대로), 알파는 흰 배경에 합성한다.</li>
 *   <li>EXIF 방향(JPEG)대로 돌린다 — 폰으로 찍은 세로 사진이 누워 보이지 않게.</li>
 *   <li>JPEG 로 다시 인코딩한다. <b>이 재인코딩이 EXIF·GPS 같은 메타데이터를 없앤다</b> —
 *       사진에 든 촬영 위치가 그대로 저장되면 안 된다.</li>
 * </ol>
 */
@Slf4j
@Component
public class RoutinePhotoProcessor {

  /// 앱이 한 번에 받는 사진 크기 상한(바이트). 서비스가 읽기 전에 검사한다.
  public static final int MAX_BYTES = 5 * 1024 * 1024;
  /// 디코드를 허락하는 원본의 긴 변 · 총 픽셀 상한.
  static final int MAX_INPUT_SIDE = 8000;
  static final long MAX_INPUT_PIXELS = 40_000_000L;
  /// 저장하는 그림의 긴 변.
  static final int OUTPUT_MAX_SIDE = 1024;
  private static final float JPEG_QUALITY = 0.85f;

  /**
   * @param raw 올라온 원본 바이트
   * @return 확장자가 항상 jpg 인, 메타데이터 없는 JPEG 바이트
   * @throws CustomException 형식이 아니거나 깨졌으면 {@code ROUTINE_STEP_IMAGE_INVALID_TYPE},
   *         너무 큰 그림이면 {@code ROUTINE_STEP_IMAGE_TOO_LARGE}
   */
  public byte[] process(byte[] raw) {
    boolean jpeg = isJpeg(raw);
    if (!jpeg && !isPng(raw)) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
    }
    BufferedImage decoded = decode(raw);
    BufferedImage rgb = toRgbScaled(decoded);
    BufferedImage oriented = jpeg ? applyOrientation(rgb, readExifOrientation(raw)) : rgb;
    return encodeJpeg(oriented);
  }

  // ── 디코드 ──────────────────────────────────────────

  private BufferedImage decode(byte[] raw) {
    ImageReader reader = null;
    try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(raw))) {
      Iterator<ImageReader> readers = input == null ? null : ImageIO.getImageReaders(input);
      if (readers == null || !readers.hasNext()) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
      }
      reader = readers.next();
      reader.setInput(input, true, true);

      // 픽셀을 풀기 전에 머리말의 크기만 읽는다.
      int width = reader.getWidth(0);
      int height = reader.getHeight(0);
      if (width <= 0 || height <= 0) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
      }
      if (Math.max(width, height) > MAX_INPUT_SIDE || (long) width * height > MAX_INPUT_PIXELS) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE);
      }

      // 아주 큰 사진은 읽으면서 솎아 메모리를 줄인다. 줄이는 목표(1024)의 2배 이상은 남긴다.
      ImageReadParam param = reader.getDefaultReadParam();
      int subsampling = Math.max(1, Math.max(width, height) / (OUTPUT_MAX_SIDE * 2));
      if (subsampling > 1) {
        param.setSourceSubsampling(subsampling, subsampling, 0, 0);
      }
      // 끝이 잘린 JPEG 는 예외 없이 경고만 내고 읽지 못한 부분을 회색으로 채워 돌려준다. 경고를 잡아 거절한다.
      // 경고 문구는 지역에 따라 번역되므로 영어로 고정한다. "Premature end" 만 본다 — 폰 사진에 흔한
      // 무해한 경고(불필요한 바이트 등)까지 거절하면 멀쩡한 사진이 막힌다.
      boolean[] truncated = {false};
      // setLocale 은 리더가 지원하지 않는 언어를 주면 예외를 던진다(PNG 리더는 지원 언어 목록이 없다).
      Locale[] supported = reader.getAvailableLocales();
      if (supported != null && java.util.Arrays.asList(supported).contains(Locale.ENGLISH)) {
        reader.setLocale(Locale.ENGLISH);
      }
      reader.addIIOReadWarningListener((source, warning) -> {
        if (warning != null && warning.toLowerCase(Locale.ROOT).contains("premature end")) {
          truncated[0] = true;
        }
      });
      BufferedImage image = reader.read(0, param);
      if (image == null || truncated[0]) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
      }
      // JPEG 에는 투명도가 없으니 4채널이면 CMYK·YCCK 다. ImageIO 가 읽기는 하지만 색 변환이 정확하지 않아
      // 색이 어긋난 그림이 저장된다(실측: 평균색이 원본보다 밝게 나왔다). 폰 카메라는 만들지 않으니 거절한다.
      if ("jpeg".equalsIgnoreCase(reader.getFormatName()) && image.getRaster().getNumBands() > 3) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
      }
      return image;
    } catch (CustomException e) {
      throw e;
    } catch (IOException | RuntimeException e) {
      // 깨진 파일, 읽지 못하는 색 공간이 여기로 온다. 사용자에겐 "이 사진은 못 쓴다"이다.
      log.warn("카드 사진 디코드 실패: {}", e.toString());
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
    } finally {
      if (reader != null) {
        reader.dispose();
      }
    }
  }

  // ── 축소 · 알파 합성 ─────────────────────────────────

  /** 긴 변을 1024 이하로 줄이면서 RGB 로 만든다. 알파는 흰 배경에 합성된다. */
  private BufferedImage toRgbScaled(BufferedImage source) {
    int width = source.getWidth();
    int height = source.getHeight();
    double scale = Math.min(1.0, (double) OUTPUT_MAX_SIDE / Math.max(width, height));
    int targetWidth = Math.max(1, (int) Math.round(width * scale));
    int targetHeight = Math.max(1, (int) Math.round(height * scale));

    // 절반씩 줄여 가며 마지막에 목표로 맞춘다 — 한 번에 크게 줄이면 계단이 진다.
    BufferedImage current = drawOnWhite(source, width, height);
    while (current.getWidth() / 2 >= targetWidth && current.getHeight() / 2 >= targetHeight) {
      current = drawOnWhite(current, current.getWidth() / 2, current.getHeight() / 2);
    }
    if (current.getWidth() != targetWidth || current.getHeight() != targetHeight) {
      current = drawOnWhite(current, targetWidth, targetHeight);
    }
    return current;
  }

  private BufferedImage drawOnWhite(BufferedImage source, int width, int height) {
    BufferedImage target = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
    Graphics2D g = target.createGraphics();
    try {
      g.setColor(Color.WHITE);
      g.fillRect(0, 0, width, height);
      g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
      g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
      g.drawImage(source, 0, 0, width, height, null);
    } finally {
      g.dispose();
    }
    return target;
  }

  // ── EXIF 방향 ───────────────────────────────────────

  /**
   * JPEG 의 EXIF 방향(1~8)을 읽는다. 없거나 깨졌으면 1(그대로).
   *
   * <p>ImageIO 의 JPEG 메타데이터에는 방향이 없어 APP1 의 TIFF 머리를 직접 읽는다. 길이·오프셋을 매번
   * 확인하고, 어디서든 어긋나면 1 로 돌아간다 — 방향을 못 읽었다고 업로드를 막을 이유는 없다.
   */
  static int readExifOrientation(byte[] jpeg) {
    try {
      int pos = 2; // SOI(FFD8) 다음
      while (pos + 4 <= jpeg.length && (jpeg[pos] & 0xFF) == 0xFF) {
        int marker = jpeg[pos + 1] & 0xFF;
        if (marker == 0xDA || marker == 0xD9) {
          break; // 이미지 데이터 시작 — 그 뒤엔 메타데이터가 없다
        }
        int length = u16(jpeg, pos + 2, false);
        int segmentStart = pos + 4;
        int segmentEnd = pos + 2 + length;
        if (length < 2 || segmentEnd > jpeg.length) {
          return 1;
        }
        if (marker == 0xE1 && segmentEnd - segmentStart >= 14 && isExifHeader(jpeg, segmentStart)) {
          return orientationFromTiff(jpeg, segmentStart + 6, segmentEnd);
        }
        pos = segmentEnd;
      }
    } catch (RuntimeException e) {
      // 배열 범위를 벗어나는 깨진 EXIF — 방향 없음으로 본다
    }
    return 1;
  }

  private static boolean isExifHeader(byte[] b, int at) {
    return b[at] == 'E' && b[at + 1] == 'x' && b[at + 2] == 'i' && b[at + 3] == 'f' && b[at + 4] == 0
      && b[at + 5] == 0;
  }

  private static int orientationFromTiff(byte[] b, int tiff, int end) {
    boolean little;
    if (b[tiff] == 'I' && b[tiff + 1] == 'I') {
      little = true;
    } else if (b[tiff] == 'M' && b[tiff + 1] == 'M') {
      little = false;
    } else {
      return 1;
    }
    long ifdOffset = u32(b, tiff + 4, little);
    long ifd = tiff + ifdOffset;
    if (ifd < tiff || ifd + 2 > end) {
      return 1;
    }
    int entries = u16(b, (int) ifd, little);
    for (int i = 0; i < entries; i++) {
      int entry = (int) ifd + 2 + i * 12;
      if (entry + 12 > end) {
        return 1;
      }
      if (u16(b, entry, little) == 0x0112) {
        int value = u16(b, entry + 8, little); // SHORT 하나는 값 칸 앞 2바이트에 들어 있다
        return value >= 1 && value <= 8 ? value : 1;
      }
    }
    return 1;
  }

  private static int u16(byte[] b, int at, boolean little) {
    int first = b[at] & 0xFF;
    int second = b[at + 1] & 0xFF;
    return little ? (second << 8) | first : (first << 8) | second;
  }

  private static long u32(byte[] b, int at, boolean little) {
    long value = 0;
    for (int i = 0; i < 4; i++) {
      int octet = b[at + (little ? 3 - i : i)] & 0xFF;
      value = (value << 8) | octet;
    }
    return value;
  }

  /**
   * 방향 값대로 돌리고 뒤집는다.
   *
   * <pre>
   *   1 그대로   2 좌우 반전   3 180도   4 상하 반전
   *   5 전치     6 시계 90도   7 반전치  8 반시계 90도
   * </pre>
   * 도착 픽셀마다 원본 좌표를 계산해 옮긴다. 이미 1024 이하로 줄어 있어 비용이 작다.
   */
  static BufferedImage applyOrientation(BufferedImage src, int orientation) {
    if (orientation <= 1 || orientation > 8) {
      return src;
    }
    int w = src.getWidth();
    int h = src.getHeight();
    boolean swap = orientation >= 5; // 5~8 은 가로세로가 바뀐다
    BufferedImage out = new BufferedImage(swap ? h : w, swap ? w : h, BufferedImage.TYPE_INT_RGB);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int dx;
        int dy;
        switch (orientation) {
          case 2 -> { dx = w - 1 - x; dy = y; }
          case 3 -> { dx = w - 1 - x; dy = h - 1 - y; }
          case 4 -> { dx = x; dy = h - 1 - y; }
          case 5 -> { dx = y; dy = x; }
          case 6 -> { dx = h - 1 - y; dy = x; }
          case 7 -> { dx = h - 1 - y; dy = w - 1 - x; }
          default -> { dx = y; dy = w - 1 - x; } // 8
        }
        out.setRGB(dx, dy, src.getRGB(x, y));
      }
    }
    return out;
  }

  // ── 인코딩 ──────────────────────────────────────────

  private byte[] encodeJpeg(BufferedImage image) {
    Iterator<ImageWriter> writers = ImageIO.getImageWritersByFormatName("jpeg");
    if (!writers.hasNext()) {
      log.error("JPEG 인코더를 찾을 수 없다");
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
    }
    ImageWriter writer = writers.next();
    try (ByteArrayOutputStream out = new ByteArrayOutputStream();
      MemoryCacheImageOutputStream stream = new MemoryCacheImageOutputStream(out)) {
      ImageWriteParam param = writer.getDefaultWriteParam();
      param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
      param.setCompressionQuality(JPEG_QUALITY);
      writer.setOutput(stream);
      // 메타데이터를 넘기지 않는다 — EXIF·GPS·썸네일이 결과에 남지 않는다.
      writer.write(null, new IIOImage(image, null, null), param);
      stream.flush();
      return out.toByteArray();
    } catch (IOException e) {
      log.warn("카드 사진 JPEG 인코딩 실패", e);
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
    } finally {
      writer.dispose();
    }
  }

  // ── 서명 ────────────────────────────────────────────

  private static boolean isJpeg(byte[] b) {
    return b != null && b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF;
  }

  private static boolean isPng(byte[] b) {
    byte[] signature = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
    if (b == null || b.length < signature.length) {
      return false;
    }
    for (int i = 0; i < signature.length; i++) {
      if (b[i] != signature[i]) {
        return false;
      }
    }
    return true;
  }
}
