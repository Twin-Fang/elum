package com.chuseok22.elumserver.link.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class LinkRoleTest {

  @Test
  @DisplayName("role 클레임이 없던 시절 토큰은 보호자로 본다 — 없다고 막으면 기존 세션이 다 끊긴다")
  void fromClaim_missingMeansGuardian() {
    assertThat(LinkRole.fromClaim(null)).isEqualTo(LinkRole.GUARDIAN);
  }

  @Test
  @DisplayName("모르는 값이 와도 보호자로 떨어뜨리되 이룸이로 올려주지는 않는다")
  void fromClaim_unknownMeansGuardian() {
    assertThat(LinkRole.fromClaim("ADMIN")).isEqualTo(LinkRole.GUARDIAN);
    assertThat(LinkRole.fromClaim("elumi")).isEqualTo(LinkRole.GUARDIAN);
  }

  @Test
  @DisplayName("정확히 적힌 값만 이룸이로 인정한다")
  void fromClaim_exact() {
    assertThat(LinkRole.fromClaim("ELUMI")).isEqualTo(LinkRole.ELUMI);
  }

  @Test
  void authority() {
    assertThat(LinkRole.ELUMI.authority()).isEqualTo("ROLE_ELUMI");
    assertThat(LinkRole.GUARDIAN.authority()).isEqualTo("ROLE_GUARDIAN");
  }
}
