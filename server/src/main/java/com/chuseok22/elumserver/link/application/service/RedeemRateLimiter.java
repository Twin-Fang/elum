package com.chuseok22.elumserver.link.application.service;

import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 연결 암호 넣기의 호출자별 속도 제한 (이슈 #200).
 *
 * <p><b>암호별 실패 횟수만으로는 막히지 않는다.</b> 그 카운터는 이미 존재하는 암호를
 * 두드릴 때만 올라간다. 무작위로 찍는 쪽은 매번 없는 값에 걸려 아무 흔적도 남기지 않고
 * 계속 시도할 수 있다. 그래서 호출자 단위로도 센다.
 *
 * <p>세는 일은 {@link SharedStateStore}에 맡긴다. 서버가 여러 대가 되면 제한이
 * 서버 수만큼 헐거워지는데 — 분당 10회가 분당 10 × 서버 수가 된다 — 그때 구현체만
 * 바꾸면 이 클래스는 그대로다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RedeemRateLimiter {

  /** 사람이 받아적어 넣는 속도로는 넉넉하다. */
  private static final int MAX_PER_WINDOW = 10;

  private static final Duration WINDOW = Duration.ofMinutes(1);
  private static final String KEY_PREFIX = "link-redeem:";

  private final SharedStateStore sharedStateStore;

  /** 시도해도 되면 true. 창 안에서 한도를 넘었으면 false. */
  public boolean tryAcquire(String caller) {
    boolean allowed = sharedStateStore.tryRecordInWindow(
      KEY_PREFIX + caller, WINDOW, MAX_PER_WINDOW, System.currentTimeMillis());
    if (!allowed) {
      log.warn("연결 암호 시도가 너무 잦습니다: caller={}", caller);
    }
    return allowed;
  }
}
