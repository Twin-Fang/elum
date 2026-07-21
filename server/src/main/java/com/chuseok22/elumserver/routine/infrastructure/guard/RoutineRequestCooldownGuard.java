package com.chuseok22.elumserver.routine.infrastructure.guard;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;

// 일과 생성/재생성은 단계 수만큼 Gemini 이미지 호출이 발생해 비용이 크므로, 회원당 최소
// 요청 간격을 두어 짧은 시간에 반복 호출되는 것을 막는다. 인스턴스가 1대뿐인 해커톤
// 배포 환경이고 Redis도 연결돼 있지 않아(server/CLAUDE.md 참고) 인메모리로 처리한다.
@Component
public class RoutineRequestCooldownGuard {

  private static final Duration DEFAULT_COOLDOWN = Duration.ofSeconds(30);

  private final Duration cooldown;
  private final ConcurrentHashMap<String, Instant> lastRequestedAt = new ConcurrentHashMap<>();

  public RoutineRequestCooldownGuard() {
    this(DEFAULT_COOLDOWN);
  }

  // 테스트에서 30초를 그대로 기다리지 않고 만료 이후 재요청 케이스를 검증할 수 있도록
  // cooldown을 주입받는 생성자를 패키지 내부에 별도로 둔다.
  RoutineRequestCooldownGuard(Duration cooldown) {
    this.cooldown = cooldown;
  }

  // 마지막 요청 시각을 원자적으로 확인·갱신한다. compute()는 하나의 락 아래에서
  // 동작하므로, 같은 회원이 동시에 두 요청을 보내도 하나만 통과한다.
  public void guard(String memberId) {
    Instant now = Instant.now();
    Instant recorded = lastRequestedAt.compute(
      memberId,
      (id, last) -> (last != null && Duration.between(last, now).compareTo(cooldown) < 0) ? last : now
    );
    if (recorded != now) {
      throw new CustomException(ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT);
    }
  }
}
