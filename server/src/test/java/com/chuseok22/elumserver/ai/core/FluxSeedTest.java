package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class FluxSeedTest {

  @Test
  @DisplayName("같은 일과면 언제 불러도 같은 seed — 카드끼리 같은 캐릭터가 나온다 (#373 2차 시험)")
  void sameRoutine_sameSeed() {
    String key = FluxSeed.routineKey("profile-1", "비 오는 날 학교에 가요");

    assertThat(FluxSeed.of(key)).isEqualTo(FluxSeed.of(FluxSeed.routineKey("profile-1", "비 오는 날 학교에 가요")));
    assertThat(FluxSeed.of(key)).isNotNegative();
  }

  @Test
  @DisplayName("다른 일과·다른 이룸이는 다른 seed")
  void differentRoutine_differentSeed() {
    Integer a = FluxSeed.of(FluxSeed.routineKey("profile-1", "비 오는 날 학교에 가요"));
    assertThat(a).isNotEqualTo(FluxSeed.of(FluxSeed.routineKey("profile-1", "빨래를 개서 정리해요")));
    assertThat(a).isNotEqualTo(FluxSeed.of(FluxSeed.routineKey("profile-2", "비 오는 날 학교에 가요")));
  }

  @Test
  @DisplayName("열쇠가 없으면 seed 를 보내지 않는다(fal 이 고른다)")
  void noKey_noSeed() {
    assertThat(FluxSeed.of(null)).isNull();
    assertThat(FluxSeed.of(" ")).isNull();
  }
}
