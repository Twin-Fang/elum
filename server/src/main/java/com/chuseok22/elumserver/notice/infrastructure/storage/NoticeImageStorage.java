package com.chuseok22.elumserver.notice.infrastructure.storage;

import com.chuseok22.elumserver.notice.core.NoticeImageType;

/**
 * 공지 이미지를 담아 두는 곳 (이슈 #370).
 *
 * <p>일과 이미지({@code RoutineImageStorage})와 같은 관례로 <b>경로가 아니라 열쇠</b>를
 * 돌려준다. 저장 위치를 옮겨도 DB 값은 그대로 쓴다.
 *
 * <p>일과 저장소를 그대로 쓰지 않은 이유 — 그쪽은 "한 번의 생성에서 만든 그림 묶음"을
 * 단위로 저장하고 지운다. 공지는 한 장씩 올리고 바꾸고 지우므로 단위가 다르다.
 */
public interface NoticeImageStorage {

  /**
   * 담고 열쇠({@code 공지아이디/임의값.확장자})를 돌려준다.
   *
   * <p>같은 공지에 다시 올려도 <b>열쇠가 매번 달라진다.</b> 앱은 이미지 주소로 캐시하므로,
   * 같은 주소에 다른 그림을 두면 바꾼 뒤에도 옛 그림이 보인다.
   */
  String save(String noticeId, byte[] bytes, NoticeImageType type);

  ImageContent read(String key);

  /**
   * 지운다. 없거나 지우지 못해도 예외를 내지 않는다 — 공지를 지우는 흐름을 이미지 한 장이
   * 막아서는 안 된다. 실패는 로그로 남긴다.
   */
  void delete(String key);

  record ImageContent(byte[] bytes, String contentType) {

  }
}
