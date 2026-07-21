package com.chuseok22.elumserver.routine.infrastructure.guard;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.time.Duration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutineRequestCooldownGuardTest {

  @Test
  @DisplayName("같은 회원이 쿨다운 시간 내에 재요청하면 ROUTINE_REQUEST_TOO_FREQUENT를 던진다")
  void guard_sameMemberWithinCooldown_throwsTooFrequent() {
    RoutineRequestCooldownGuard guard = new RoutineRequestCooldownGuard(Duration.ofSeconds(30));

    guard.guard("member-1");

    assertThatThrownBy(() -> guard.guard("member-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT));
  }

  @Test
  @DisplayName("다른 회원의 요청은 서로의 쿨다운에 영향을 받지 않는다")
  void guard_differentMembers_doNotBlockEachOther() {
    RoutineRequestCooldownGuard guard = new RoutineRequestCooldownGuard(Duration.ofSeconds(30));

    guard.guard("member-1");

    assertThatCode(() -> guard.guard("member-2")).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("쿨다운 시간이 지나면 같은 회원도 다시 요청할 수 있다")
  void guard_afterCooldownExpires_allowsSameMemberAgain() throws InterruptedException {
    RoutineRequestCooldownGuard guard = new RoutineRequestCooldownGuard(Duration.ofMillis(20));

    guard.guard("member-1");
    Thread.sleep(30);

    assertThatCode(() -> guard.guard("member-1")).doesNotThrowAnyException();
  }
}
