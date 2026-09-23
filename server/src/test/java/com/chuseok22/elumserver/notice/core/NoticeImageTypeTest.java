package com.chuseok22.elumserver.notice.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 올린 파일이 실제로 png, jpg, webp 인지 (이슈 #370, N16).
 *
 * <p>파일 이름이나 브라우저가 붙인 Content-Type 은 믿지 않는다. 이름만 {@code .png} 로 바꾼
 * SVG 는 스크립트를 담을 수 있다. 첫 몇 바이트(서명)로 가린다.
 */
class NoticeImageTypeTest {

  static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0};
  static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0, 0, 0, 0, 0, 0, 0};
  static final byte[] WEBP = "RIFF\0\0\0\0WEBPVP8 ".getBytes(StandardCharsets.ISO_8859_1);

  @Test
  @DisplayName("png, jpg, webp 는 서명으로 알아본다")
  void detectsAllowedTypes() {
    assertThat(NoticeImageType.detect(PNG)).contains(NoticeImageType.PNG);
    assertThat(NoticeImageType.detect(JPEG)).contains(NoticeImageType.JPEG);
    assertThat(NoticeImageType.detect(WEBP)).contains(NoticeImageType.WEBP);
  }

  @Test
  @DisplayName("gif, svg, 빈 파일은 받지 않는다")
  void rejectsOthers() {
    assertThat(NoticeImageType.detect("GIF89a......".getBytes(StandardCharsets.ISO_8859_1))).isEmpty();
    assertThat(NoticeImageType.detect("<svg xmlns=\"http://www.w3.org/2000/svg\">"
      .getBytes(StandardCharsets.UTF_8))).isEmpty();
    assertThat(NoticeImageType.detect(new byte[0])).isEmpty();
    assertThat(NoticeImageType.detect(null)).isEmpty();
  }

  @Test
  @DisplayName("RIFF 로 시작해도 WEBP 가 아니면(wav 등) 받지 않는다")
  void riffButNotWebp_rejected() {
    assertThat(NoticeImageType.detect("RIFF\0\0\0\0WAVEfmt ".getBytes(StandardCharsets.ISO_8859_1))).isEmpty();
  }

  @Test
  @DisplayName("저장 확장자와 응답 Content-Type 을 함께 준다")
  void extensionAndContentType() {
    assertThat(NoticeImageType.JPEG.getExtension()).isEqualTo("jpg");
    assertThat(NoticeImageType.JPEG.getContentType()).isEqualTo("image/jpeg");
    assertThat(NoticeImageType.fromKey("abc/1f2e.webp")).contains(NoticeImageType.WEBP);
    assertThat(NoticeImageType.fromKey("abc/1f2e.svg")).isEmpty();
  }
}
