package com.chuseok22.elumserver.notice.core;

import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 공지가 지금 어떤 상태인지 (이슈 #370).
 *
 * <p>관리자 목록의 배지와 앱 API 가 <b>이 한 곳의 판단</b>을 쓴다. 따로 계산하면
 * 목록에는 "게시 중"인데 앱에는 안 뜨는 공지가 생긴다.
 */
@Getter
@AllArgsConstructor
public enum NoticeStatus {

  SCHEDULED("예약"),
  LIVE("게시 중"),
  ENDED("끝남"),
  DISABLED("꺼짐"),
  ;

  private final String label;

  /**
   * 시작은 그 순간부터 포함하고, 종료는 그 순간부터 빠진다({@code [시작, 종료)}).
   * 종료가 없으면 끌 때까지 나간다.
   *
   * <p>{@code now} 는 부르는 쪽이 서버 시계(한국 시각)로 넘긴다 — 기기 시간이 틀려도
   * 끝난 공지가 뜨지 않게 판단은 서버에서만 한다.
   */
  public static NoticeStatus of(
    boolean enabled, LocalDateTime startsAt, LocalDateTime endsAt, LocalDateTime now
  ) {
    if (!enabled) {
      return DISABLED;
    }
    if (now.isBefore(startsAt)) {
      return SCHEDULED;
    }
    if (endsAt != null && !now.isBefore(endsAt)) {
      return ENDED;
    }
    return LIVE;
  }

  public boolean isLive() {
    return this == LIVE;
  }
}
