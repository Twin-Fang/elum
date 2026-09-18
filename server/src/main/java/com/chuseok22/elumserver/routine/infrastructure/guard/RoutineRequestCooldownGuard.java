package com.chuseok22.elumserver.routine.infrastructure.guard;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 일과 생성·재생성은 단계 수만큼 이미지 호출이 발생해 비용이 크므로, 회원당 최소 요청
 * 간격을 두어 짧은 시간에 반복 호출되는 것을 막는다.
 *
 * <p>기억하는 일은 {@link SharedStateStore}에 맡긴다. 서버가 여러 대가 되면 각자
 * 자기 메모리만 봐서 <b>쿨다운이 서버 수만큼 뚫린다</b> — 일과 하나가 최대 550원이므로
 * 그대로 두면 돈이 샌다. 저장 자리를 밖으로 빼두면 그때 구현체만 바꾸면 된다.
 */
@Component
public class RoutineRequestCooldownGuard {

  private static final Duration DEFAULT_COOLDOWN = Duration.ofSeconds(30);
  private static final String KEY_PREFIX = "routine-cooldown:";

  private final SharedStateStore sharedStateStore;
  private final Duration cooldown;

  // 생성자가 둘이면 스프링이 어느 것으로 만들지 알 수 없다. 예전에는 인자 없는
  // 생성자가 있어 그것이 쓰였지만 지금은 둘 다 인자를 받으므로 명시해야 한다.
  // 이것을 빠뜨리면 서버가 아예 뜨지 않는다.
  @Autowired
  public RoutineRequestCooldownGuard(SharedStateStore sharedStateStore) {
    this(sharedStateStore, DEFAULT_COOLDOWN);
  }

  // 테스트에서 30초를 그대로 기다리지 않고 만료 이후 재요청 케이스를 검증할 수 있도록
  // cooldown을 주입받는 생성자를 패키지 내부에 별도로 둔다.
  RoutineRequestCooldownGuard(SharedStateStore sharedStateStore, Duration cooldown) {
    this.sharedStateStore = sharedStateStore;
    this.cooldown = cooldown;
  }

  /// 쿨다운 안에 다시 오면 거부한다. 같은 회원이 동시에 두 요청을 보내도 하나만 통과한다.
  public void guard(String memberId) {
    boolean allowed = sharedStateStore.firstSeen(
      KEY_PREFIX + memberId, cooldown, System.currentTimeMillis());
    if (!allowed) {
      throw new CustomException(ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT);
    }
  }
}
