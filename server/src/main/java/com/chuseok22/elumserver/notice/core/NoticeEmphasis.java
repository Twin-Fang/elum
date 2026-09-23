package com.chuseok22.elumserver.notice.core;

/**
 * 제목 강조 표기 {@code **…**} (이슈 #370).
 *
 * <p>표기는 이것 한 가지뿐이다. 왼쪽부터 {@code **} 로 나눈 조각 중 홀수 번째(1, 3, …)가
 * 강조다. 앱과 관리자 미리보기({@code notice-preview.js})도 같은 규칙으로 그린다 —
 * 규칙이 어긋나면 미리보기와 앱에서 강조되는 곳이 달라진다.
 *
 * <p>서버는 표기를 그대로 저장하고 그대로 보낸다. 여기서는 짝만 본다.
 */
public final class NoticeEmphasis {

  private static final String MARKER = "**";

  private NoticeEmphasis() {
  }

  /** {@code **} 가 짝수 번 나오면 짝이 맞다. 나오지 않아도(0번) 맞다. */
  public static boolean isPaired(String title) {
    if (title == null || title.isEmpty()) {
      return true;
    }
    // split(-1) 은 끝의 빈 조각도 남긴다. 조각 수가 홀수면 표기가 짝수 번이다.
    return title.split("\\*\\*", -1).length % 2 == 1;
  }

  /**
   * 표기를 걷어낸, 화면에 실제로 보이는 글자.
   *
   * <p>{@code ****} 처럼 표기만 있는 제목은 저장하면 빈 제목이 된다. 비었는지는 이것으로 본다.
   */
  public static String visibleText(String title) {
    return title == null ? "" : title.replace(MARKER, "");
  }
}
