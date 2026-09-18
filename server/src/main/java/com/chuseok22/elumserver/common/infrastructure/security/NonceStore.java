package com.chuseok22.elumserver.common.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 재전송 방지용 nonce 저장소.
 *
 * <p>기억하는 일은 {@link SharedStateStore}에 맡긴다. 서버가 여러 대가 되면 각자
 * 자기 메모리만 봐서 <b>같은 요청을 서버 수만큼 재생할 수 있게 되는데</b>, 저장 자리를
 * 밖으로 빼두면 그때 구현체만 바꾸면 된다.
 */
@Component
@RequiredArgsConstructor
public class NonceStore {

  /// timestamp 허용오차(±5분)보다 넉넉히 잡는다.
  private static final Duration TTL = Duration.ofMinutes(10);
  private static final String KEY_PREFIX = "nonce:";

  private final SharedStateStore sharedStateStore;

  /// 처음 보는 nonce면 기억하고 true, 이미 유효 범위 안에서 본 적 있으면 false.
  public boolean checkAndRemember(String nonce, long nowMillis) {
    return sharedStateStore.firstSeen(KEY_PREFIX + nonce, TTL, nowMillis);
  }
}
