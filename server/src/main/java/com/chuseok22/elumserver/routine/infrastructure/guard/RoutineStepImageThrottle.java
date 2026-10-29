package com.chuseok22.elumserver.routine.infrastructure.guard;

import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import com.chuseok22.elumserver.systemconfig.application.service.UsageLimitSettings;
import java.time.Duration;
import org.springframework.stereotype.Component;

/**
 * 보호자가 직접 추가한 카드의 그림 횟수를 회원별로 묶는다.
 *
 * <p>한 일과의 카드는 10장까지지만 지우면 자리가 다시 나므로, 추가·삭제를 되풀이하면 그림 호출에 끝이 없다.
 *
 * <p><b>일과 만들기의 30초 쿨다운과 열쇠를 나눈다.</b> 같은 열쇠를 쓰면 일과를 만든 직후 카드를 고치는 보호자의 그림이 빠진다.
 * 한 번에 하나가 아니라 <b>창으로 센다</b> — 카드를 연달아 넣는 보호자는 그림을 잃지 않고 기계적인 반복만 걸린다.
 * 10분에 10장이면 한 계정의 하루 추가 그림은 1,440장으로 묶인다.
 *
 * <p>넘어도 거절하지 않는다. 부르는 쪽이 그림만 건너뛰고 카드는 둔다 — 카드 추가를 막으면 보호자가 일과를 못 고친다.
 */
@Component
public class RoutineStepImageThrottle {

  // 창 길이: 설정 키 ROUTINE_STEP_IMAGE_LIMIT_PER_10_MINUTES 의 "10분"과 함께 바꾼다
  static final Duration WINDOW = Duration.ofMinutes(10);
  private static final String KEY_PREFIX = "routine-step-image:";

  private final SharedStateStore sharedStateStore;
  private final UsageLimitSettings usageLimitSettings;

  public RoutineStepImageThrottle(SharedStateStore sharedStateStore, UsageLimitSettings usageLimitSettings) {
    this.sharedStateStore = sharedStateStore;
    this.usageLimitSettings = usageLimitSettings;
  }

  /// 이 회원에게 그림을 한 장 더 만들어도 되는가. 되면 그 한 장을 센다.
  public boolean tryAcquire(String memberId) {
    return sharedStateStore.tryRecordInWindow(
      KEY_PREFIX + memberId, WINDOW, usageLimitSettings.routineStepImageLimitPerTenMinutes(),
      System.currentTimeMillis());
  }
}
