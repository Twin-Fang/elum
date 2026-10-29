package com.chuseok22.elumserver.talk.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 피드 cursor: 왕복이 되고, 형식이 틀리면 첫 쪽으로 돌아가도록 empty 를 준다.
class TalkCursorTest {

  @Test
  @DisplayName("인코딩한 cursor 를 디코딩하면 같은 위치가 나온다")
  void encodeThenDecode_roundTrips() {
    LocalDateTime createdAt = LocalDateTime.of(2026, 10, 20, 9, 30, 15, 123_456_000);

    TalkCursor decoded = TalkCursor.decode(TalkCursor.encode(createdAt, "post-1")).orElseThrow();

    assertThat(decoded.createdAt()).isEqualTo(createdAt);
    assertThat(decoded.id()).isEqualTo("post-1");
  }

  @Test
  @DisplayName("형식이 틀리거나 비어 있으면 empty")
  void malformed_isEmpty() {
    assertThat(TalkCursor.decode("garbage")).isEmpty();
    assertThat(TalkCursor.decode("not-a-time|post-1")).isEmpty();
    assertThat(TalkCursor.decode("2026-10-20T09:30:15|")).isEmpty();
    assertThat(TalkCursor.decode("|post-1")).isEmpty();
    assertThat(TalkCursor.decode("")).isEmpty();
    assertThat(TalkCursor.decode(null)).isEmpty();
  }
}
