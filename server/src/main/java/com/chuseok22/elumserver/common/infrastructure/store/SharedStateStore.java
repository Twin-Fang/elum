package com.chuseok22.elumserver.common.infrastructure.store;

import java.time.Duration;

/**
 * 여러 서버가 <b>함께 봐야 하는</b> 짧은 수명의 상태.
 *
 * <p>재전송 방지·시도 제한·쿨다운은 모두 "짧은 시간 동안 뭔가를 기억한다"는 같은 일을
 * 한다. 서버가 한 대일 때는 각자 메모리에 들고 있어도 되지만, 여러 대가 되면 각 서버가
 * 자기 것만 세게 되어 <b>제한이 서버 수만큼 헐거워진다.</b>
 *
 * <p>그래서 저장 자리를 하나로 모았다. 수평 확장으로 갈 때 <b>이 인터페이스의 구현체
 * 하나만</b> 만들면 세 기능이 한꺼번에 해결된다. 각각 따로 고치면 세 번 일한다.
 *
 * <p>모든 메서드가 시각을 밖에서 받는다. 만료·창 경계를 테스트에서 시계 조작 없이
 * 확인하기 위해서다.
 */
public interface SharedStateStore {

  // 경계 규칙 — 다른 구현체를 만들 때 여기에 맞춘다.
  // 정확히 기간만큼 지난 시점은 "지난 것"으로 본다. 만료 시각 = 풀리는 시각이다.

  /**
   * 이 열쇠를 {@code ttl} 안에 처음 보는가.
   *
   * <p>처음이면 기억하고 true. 이미 유효 기간 안에 본 적이 있으면 false.
   * 재전송 방지와 쿨다운이 쓴다.
   */
  boolean firstSeen(String key, Duration ttl, long nowMillis);

  /**
   * 창 안 횟수가 {@code max} 미만이면 기록하고 true, 아니면 기록하지 않고 false.
   *
   * <p><b>거부된 시도는 창에 남기지 않는다.</b> 남기면 한 번 막힌 사람이 계속 두드릴 때
   * 창이 영영 열리지 않아, 정상 사용자가 실수로 한도를 넘겼을 때 빠져나올 수 없다.
   *
   * <p>세기와 기록이 한 번에 일어나야 한다 — 나눠서 하면 동시에 들어온 요청이 둘 다
   * 통과한다.
   */
  boolean tryRecordInWindow(String key, Duration window, int max, long nowMillis);
}
