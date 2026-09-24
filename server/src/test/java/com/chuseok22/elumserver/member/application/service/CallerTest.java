package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.jwt.AccessTokenDetails;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

class CallerTest {

  private UsernamePasswordAuthenticationToken auth(String linkId) {
    UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken("m1", null, List.of());
    auth.setDetails(new AccessTokenDetails(linkId));
    return auth;
  }

  @Test
  @DisplayName("이룸이 휴대폰 인증이면 연결 ID 와 헤더를 함께 담는다")
  void from_elumiAuthentication_carriesLinkAndHeader() {
    Caller caller = Caller.from(auth("l1"), "p1");

    assertThat(caller).isEqualTo(new Caller("m1", "l1", "p1"));
    assertThat(caller.isElumi()).isTrue();
  }

  @Test
  @DisplayName("헤더가 비었거나 공백이면 없는 것으로 본다 — 가장 먼저 연결된 이룸이를 쓴다")
  void from_blankHeader_isAbsent() {
    assertThat(Caller.from(auth(null), "  ").profileId()).isNull();
    assertThat(Caller.from(auth(null), null).profileId()).isNull();
    assertThat(Caller.from(auth(null)).isElumi()).isFalse();
  }

  @Test
  @DisplayName("details 가 없는 인증(옛 테스트·다른 경로)은 보호자로 본다")
  void from_authenticationWithoutDetails_isGuardian() {
    Caller caller = Caller.from(new UsernamePasswordAuthenticationToken("m1", null, List.of()), "p1");

    assertThat(caller).isEqualTo(Caller.guardian("m1", "p1"));
  }
}
