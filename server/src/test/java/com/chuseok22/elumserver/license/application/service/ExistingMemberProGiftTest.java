package com.chuseok22.elumserver.license.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;

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
 * 기존 가입자 Pro 선물 판정: 이 테스트가 깨지면 선물 대상이 Pro 를 못 받거나, 대상 아닌 회원이 Pro 를 공짜로 받는다
 */
@ExtendWith(MockitoExtension.class)
class ExistingMemberProGiftTest {

  private static final String MEMBER_ID = "m1";

  @Mock
  private SystemConfigService systemConfigService;

  @Mock
  private MemberSignupTimeService memberSignupTimeService;

  @InjectMocks
  private ExistingMemberProGift existingMemberProGift;

  private void givenGift(boolean isEnabled, String joinedBefore, String endsAt) {
    lenient().when(systemConfigService.getBoolean(ConfigKey.EXISTING_MEMBER_PRO_GIFT_ENABLED)).thenReturn(isEnabled);
    lenient().when(systemConfigService.getString(ConfigKey.EXISTING_MEMBER_PRO_GIFT_JOINED_BEFORE)).thenReturn(joinedBefore);
    lenient().when(systemConfigService.getString(ConfigKey.EXISTING_MEMBER_PRO_GIFT_ENDS_AT)).thenReturn(endsAt);
  }

  private void givenSignedUpAt(LocalDateTime signupAt) {
    lenient().when(memberSignupTimeService.findSignupAt(MEMBER_ID)).thenReturn(Optional.ofNullable(signupAt));
  }

  @Test
  @DisplayName("기준 시각 전에 가입했고 종료 전이면 종료 시각을 준다")
  void giftEndsAt_insideWindow_returnsEnd() {
    givenGift(true, "2026-11-20T00:00", "2099-05-20 00:00");
    givenSignedUpAt(LocalDateTime.of(2026, 3, 1, 9, 0));

    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).contains(LocalDateTime.of(2099, 5, 20, 0, 0));
  }

  @Test
  @DisplayName("기준 시각에 맞춰 또는 뒤에 가입한 회원은 받지 않는다")
  void giftEndsAt_joinedOnOrAfterCutoff_empty() {
    givenGift(true, "2026-11-20T00:00", "2099-05-20");
    givenSignedUpAt(LocalDateTime.of(2026, 11, 20, 0, 0));
    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).isEmpty();

    givenSignedUpAt(LocalDateTime.of(2026, 11, 21, 0, 0));
    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).isEmpty();
  }

  @Test
  @DisplayName("종료 시각이 지나면 받지 않는다 (Free 로 돌아감)")
  void giftEndsAt_afterEnd_empty() {
    givenGift(true, "2026-01-01", LocalDateTime.now().minusMinutes(1).toString());
    givenSignedUpAt(LocalDateTime.of(2025, 6, 1, 0, 0));

    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).isEmpty();
  }

  @Test
  @DisplayName("꺼져 있거나 시각이 비어 있으면 받지 않는다 — 기본값은 꺼짐이라 배포만으로 바뀌지 않는다")
  void giftEndsAt_disabledOrBlank_empty() {
    givenSignedUpAt(LocalDateTime.of(2025, 6, 1, 0, 0));
    givenGift(false, "2026-11-20", "2099-05-20");
    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).isEmpty();

    givenGift(true, "", "2099-05-20");
    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).isEmpty();

    givenGift(true, "2026-11-20", " ");
    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).isEmpty();

    assertThat(ConfigKey.EXISTING_MEMBER_PRO_GIFT_ENABLED.getDefaultValue()).isEqualTo("false");
  }

  @Test
  @DisplayName("날짜 형식 오류·회원 조회 실패는 선물 없음으로 (막지도 열지도 않음)")
  void giftEndsAt_badDateOrLookupFailure_empty() {
    givenGift(true, "다음 주", "2099-05-20");
    givenSignedUpAt(LocalDateTime.of(2025, 6, 1, 0, 0));
    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).isEmpty();

    givenGift(true, "2026-11-20", "2099-05-20");
    lenient().when(memberSignupTimeService.findSignupAt(MEMBER_ID)).thenThrow(new RuntimeException("DB 장애"));
    assertThat(existingMemberProGift.giftEndsAt(MEMBER_ID)).isEmpty();
  }
}
