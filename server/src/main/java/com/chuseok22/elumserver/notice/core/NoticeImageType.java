package com.chuseok22.elumserver.notice.core;

import java.util.Optional;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 공지 이미지로 받는 형식 (이슈 #370).
 *
 * <p><b>파일 이름과 브라우저가 붙인 Content-Type 은 믿지 않는다.</b> 이름만 {@code .png} 로
 * 바꾼 SVG 는 스크립트를 담을 수 있고, 그 파일을 공개 API 로 그대로 내보내게 된다.
 * 첫 몇 바이트(서명)로 가린다.
 */
@Getter
@AllArgsConstructor
public enum NoticeImageType {

  PNG("png", "image/png"),
  JPEG("jpg", "image/jpeg"),
  WEBP("webp", "image/webp"),
  ;

  private final String extension;
  private final String contentType;

  public static Optional<NoticeImageType> detect(byte[] bytes) {
    if (bytes == null) {
      return Optional.empty();
    }
    if (startsWith(bytes, 0, (byte) 0x89, (byte) 'P', (byte) 'N', (byte) 'G', (byte) 0x0D, (byte) 0x0A,
      (byte) 0x1A, (byte) 0x0A)) {
      return Optional.of(PNG);
    }
    if (startsWith(bytes, 0, (byte) 0xFF, (byte) 0xD8, (byte) 0xFF)) {
      return Optional.of(JPEG);
    }
    // WEBP 는 RIFF 컨테이너다. RIFF 만 보면 wav·avi 도 통과하므로 8번째부터 WEBP 까지 본다.
    if (startsWith(bytes, 0, (byte) 'R', (byte) 'I', (byte) 'F', (byte) 'F')
      && startsWith(bytes, 8, (byte) 'W', (byte) 'E', (byte) 'B', (byte) 'P')) {
      return Optional.of(WEBP);
    }
    return Optional.empty();
  }

  /** 저장된 열쇠의 확장자로 응답 형식을 정한다. 저장할 때 서명으로 정한 확장자다. */
  public static Optional<NoticeImageType> fromKey(String key) {
    if (key == null) {
      return Optional.empty();
    }
    int dot = key.lastIndexOf('.');
    String extension = dot < 0 ? "" : key.substring(dot + 1);
    for (NoticeImageType type : values()) {
      if (type.extension.equalsIgnoreCase(extension)) {
        return Optional.of(type);
      }
    }
    return Optional.empty();
  }

  private static boolean startsWith(byte[] bytes, int offset, byte... signature) {
    if (bytes.length < offset + signature.length) {
      return false;
    }
    for (int i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) {
        return false;
      }
    }
    return true;
  }
}
