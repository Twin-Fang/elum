package com.chuseok22.elumserver.license.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.application.service.MemberSignupTimeService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 신규가입 Pro 체험 판정: 깨지면 대상 가입자가 체험을 못 받거나, 대상 아닌 회원이 Pro 를 공짜로 받는다
 */
@ExtendWith(MockitoExtension.class)
class SignupProEventTest {

  private static final String MEMBER_ID = "m1";

  @Mock
  private SystemConfigService systemConfigService;

  @Mock
  private MemberSignupTimeService memberSignupTimeService;

  @InjectMocks
  private SignupProEvent signupProEvent;

  private void givenEvent(boolean isEnabled, String startAt, String endAt, int grantDays) {
    lenient().when(systemConfigService.getBoolean(ConfigKey.SIGNUP_PRO_EVENT_ENABLED)).thenReturn(isEnabled);
    lenient().when(systemConfigService.getString(ConfigKey.SIGNUP_PRO_EVENT_START_AT)).thenReturn(startAt);
    lenient().when(systemConfigService.getString(ConfigKey.SIGNUP_PRO_EVENT_END_AT)).thenReturn(endAt);
    lenient().when(systemConfigService.getInt(ConfigKey.SIGNUP_PRO_EVENT_GRANT_DAYS)).thenReturn(grantDays);
  }

  private void givenSignedUpAt(LocalDateTime signupAt) {
    lenient().when(memberSignupTimeService.findSignupAt(MEMBER_ID)).thenReturn(Optional.ofNullable(signupAt));
  }

  @Test
  @DisplayName("이벤트가 꺼져 있으면(기본값) 가입 기간 안이어도 체험이 없다 — 배포만으로 아무도 Pro 가 되면 안 된다")
  void trialEndsAt_disabled_empty() {
    givenEvent(false, "2026-01-01", "2099-01-01", 30);
    givenSignedUpAt(LocalDateTime.now());

    assertThat(signupProEvent.trialEndsAt(MEMBER_ID)).isEmpty();
  }

  @Test
  @DisplayName("가입 기간 안에 가입했고 유지 일수 안이면 가입 시각 + 유지 일수가 종료 시각이다")
  void trialEndsAt_insideWindow_returnsSignupPlusGrantDays() {
    LocalDateTime signupAt = LocalDateTime.now().minusDays(1);
    givenEvent(true, "2026-01-01T00:00", "2099-01-01 00:00", 7);
    givenSignedUpAt(signupAt);

    assertThat(signupProEvent.trialEndsAt(MEMBER_ID)).contains(signupAt.plusDays(7));
  }

  @Test
  @DisplayName("가입 기간 밖(시작 전·종료 후)에 가입했으면 체험이 없다")
  void trialEndsAt_outsideWindow_empty() {
    givenEvent(true, "2026-01-01", "2026-02-01", 100000);

    givenSignedUpAt(LocalDateTime.of(2025, 12, 31, 23, 59));
    assertThat(signupProEvent.trialEndsAt(MEMBER_ID)).isEmpty();

    givenSignedUpAt(LocalDateTime.of(2026, 2, 1, 0, 1));
    assertThat(signupProEvent.trialEndsAt(MEMBER_ID)).isEmpty();
  }

  @Test
  @DisplayName("유지 일수가 지나면 체험이 끝난다 — 끝난 뒤에도 Pro 가 남는다")
  void trialEndsAt_grantExpired_empty() {
    givenEvent(true, "2026-01-01", "2099-01-01", 7);
    givenSignedUpAt(LocalDateTime.now().minusDays(8));

    assertThat(signupProEvent.trialEndsAt(MEMBER_ID)).isEmpty();
  }

  @Test
  @DisplayName("설정 오류(날짜 형식·빈 기간)와 회원 조회 실패는 체험 없음으로 폴백한다 — 앱이 막히면 안 된다")
  void trialEndsAt_errors_fallBackToEmpty() {
    givenEvent(true, "어제", "2099-01-01", 30);
    givenSignedUpAt(LocalDateTime.now());
    assertThat(signupProEvent.trialEndsAt(MEMBER_ID)).isEmpty();

    givenEvent(true, "", "", 30);
    assertThat(signupProEvent.trialEndsAt(MEMBER_ID)).isEmpty();

    givenEvent(true, "2026-01-01", "2099-01-01", 30);
    when(memberSignupTimeService.findSignupAt(MEMBER_ID)).thenThrow(new RuntimeException("DB 장애"));
    assertThat(signupProEvent.trialEndsAt(MEMBER_ID)).isEmpty();
  }
}
