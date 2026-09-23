package com.chuseok22.elumserver.notice.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 공지가 지금 앱에 나가는지 (이슈 #370).
 *
 * <p>관리자 목록의 배지와 앱 API 가 <b>같은 판단</b>을 써야 한다. 둘이 따로 계산하면
 * 목록에는 "게시 중"인데 앱에는 안 뜨는 공지가 생긴다.
 */
class NoticeStatusTest {

  private static final LocalDateTime START = LocalDateTime.of(2026, 9, 23, 10, 0);
  private static final LocalDateTime END = LocalDateTime.of(2026, 9, 30, 10, 0);

  @Test
  @DisplayName("꺼 두면 기간 안이어도 꺼짐이다 — 켜고 끄기는 기간과 별개다")
  void disabled_isOffEvenInsidePeriod() {
    assertThat(NoticeStatus.of(false, START, END, START.plusDays(1))).isEqualTo(NoticeStatus.DISABLED);
    assertThat(NoticeStatus.DISABLED.isLive()).isFalse();
  }

  @Test
  @DisplayName("시작 전이면 예약이다")
  void beforeStart_isScheduled() {
    assertThat(NoticeStatus.of(true, START, END, START.minusSeconds(1))).isEqualTo(NoticeStatus.SCHEDULED);
  }

  @Test
  @DisplayName("시작 시각 그 순간부터 게시 중이다")
  void atStart_isLive() {
    assertThat(NoticeStatus.of(true, START, END, START)).isEqualTo(NoticeStatus.LIVE);
    assertThat(NoticeStatus.LIVE.isLive()).isTrue();
  }

  @Test
  @DisplayName("종료 시각 그 순간부터 끝남이다 — 종료는 포함하지 않는다")
  void atEnd_isEnded() {
    assertThat(NoticeStatus.of(true, START, END, END.minusSeconds(1))).isEqualTo(NoticeStatus.LIVE);
    assertThat(NoticeStatus.of(true, START, END, END)).isEqualTo(NoticeStatus.ENDED);
  }

  @Test
  @DisplayName("종료를 비우면 끌 때까지 게시 중이다")
  void noEnd_staysLive() {
    assertThat(NoticeStatus.of(true, START, null, START.plusYears(3))).isEqualTo(NoticeStatus.LIVE);
  }

  @Test
  @DisplayName("배지 글자는 예약, 게시 중, 끝남, 꺼짐이다")
  void labels() {
    assertThat(NoticeStatus.SCHEDULED.getLabel()).isEqualTo("예약");
    assertThat(NoticeStatus.LIVE.getLabel()).isEqualTo("게시 중");
    assertThat(NoticeStatus.ENDED.getLabel()).isEqualTo("끝남");
    assertThat(NoticeStatus.DISABLED.getLabel()).isEqualTo("꺼짐");
  }
}
