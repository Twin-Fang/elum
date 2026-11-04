package com.chuseok22.elumserver.systemconfig.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 새 서버 주소 규칙 (#1053)
 * 깨지면: 관리자 오타 하나로 앱과 광고 보상 콜백이 엉뚱한 주소로 간다
 */
class ServerAddressPolicyTest {

  @Test
  @DisplayName("허용 도메인의 https 주소만 받는다 (끝 / 하나는 허용)")
  void allowedHosts_accepted() {
    assertThat(ServerAddressPolicy.isAllowed("https://api.elum.suhsaechan.kr")).isTrue();
    assertThat(ServerAddressPolicy.isAllowed("https://api.elum.chuseok22.com/")).isTrue();
  }

  @Test
  @DisplayName("http, 다른 도메인, 경로·쿼리·포트·계정 정보가 있으면 거부")
  void otherShapes_rejected() {
    assertThat(ServerAddressPolicy.isAllowed("http://api.elum.suhsaechan.kr")).isFalse();
    assertThat(ServerAddressPolicy.isAllowed("https://evil.example.com")).isFalse();
    assertThat(ServerAddressPolicy.isAllowed("https://api.elum.suhsaechan.kr/api")).isFalse();
    assertThat(ServerAddressPolicy.isAllowed("https://api.elum.suhsaechan.kr?x=1")).isFalse();
    assertThat(ServerAddressPolicy.isAllowed("https://api.elum.suhsaechan.kr:8443")).isFalse();
    assertThat(ServerAddressPolicy.isAllowed("https://user@api.elum.suhsaechan.kr")).isFalse();
    assertThat(ServerAddressPolicy.isAllowed("")).isFalse();
    assertThat(ServerAddressPolicy.isAllowed(null)).isFalse();
  }
}
