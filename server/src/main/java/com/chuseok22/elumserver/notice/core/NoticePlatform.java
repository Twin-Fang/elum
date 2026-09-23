package com.chuseok22.elumserver.notice.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.Locale;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 공지를 받을 플랫폼 (이슈 #370). 스토어별 안내가 있을 수 있어 나눈다.
 */
@Getter
@AllArgsConstructor
public enum NoticePlatform {

  ALL("전체"),
  IOS("iOS"),
  ANDROID("Android"),
  ;

  private final String label;

  /**
   * 이 공지를 {@code requested} 플랫폼 앱에 보여주는가.
   *
   * <p>전체 공지는 어느 앱에나 나간다. 앱이 플랫폼을 알려주지 않으면({@code ALL}) 전체 공지만
   * 준다 — 한쪽 스토어용 안내가 다른 쪽에 새지 않게.
   */
  public boolean reaches(NoticePlatform requested) {
    return this == ALL || this == requested;
  }

  /**
   * 요청·폼 값을 읽는다. 비었으면 {@code ALL}, 대소문자는 가리지 않는다.
   * 모르는 값은 400 이다 — 조용히 전체로 바꾸면 앱 쪽 오타가 드러나지 않는다.
   */
  public static NoticePlatform parse(String raw) {
    if (raw == null || raw.isBlank()) {
      return ALL;
    }
    try {
      return valueOf(raw.strip().toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException e) {
      throw new CustomException(ErrorCode.NOTICE_PLATFORM_INVALID);
    }
  }
}
