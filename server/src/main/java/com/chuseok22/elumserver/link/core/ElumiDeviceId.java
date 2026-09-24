package com.chuseok22.elumserver.link.core;

/**
 * 이룸이 휴대폰 세션을 가리키는 기기 값 {@code elumi-{연결 ID}} (이슈 #200, #359).
 *
 * <p><b>서버가 만든다.</b> 앱은 기기 값을 보내지 않아 {@code refresh_token.device_id}가 비어
 * 있기 쉽고, 비어 있으면 연결을 끊어도 짚을 대상이 없다. 연결할 때 서버가 이 값을 리프레시
 * 토큰에 남기고, 갱신은 이 값으로 이룸이 휴대폰인지와 어느 연결인지를 되찾는다.
 *
 * <p>만드는 쪽(연결)과 읽는 쪽(갱신)이 규칙을 따로 들고 있으면 한쪽만 바뀌었을 때 이룸이
 * 휴대폰이 보호자로 보이게 되므로 여기 한 곳에만 둔다.
 */
public final class ElumiDeviceId {

  private static final String PREFIX = "elumi-";

  /** 이룸이 휴대폰 기기 값 전체를 고르는 LIKE 패턴. 보호자 세션만 끊을 때 이것을 뺀다 (다중 보호자 E34). */
  public static final String LIKE_PATTERN = PREFIX + "%";

  private ElumiDeviceId() {
  }

  public static String of(String linkId) {
    return PREFIX + linkId;
  }

  /** 이룸이 휴대폰 기기 값이면 연결 ID, 아니면 null. */
  public static String linkIdOf(String deviceId) {
    if (deviceId == null || !deviceId.startsWith(PREFIX)) {
      return null;
    }
    return deviceId.substring(PREFIX.length());
  }
}
