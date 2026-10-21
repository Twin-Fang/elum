package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import com.chuseok22.elumserver.systemconfig.application.service.UsageLimitSettings;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 초대 코드 발급·입력의 계정별 시도 제한.
 *
 * <p>연결 암호는 호출자(IP)별로만 센다. 초대 코드는 로그인한 계정이 부르므로 <b>계정별</b>로 센다 — 코드 하나의
 * 실패 횟수는 존재하는 코드를 두드릴 때만 오른다. 무작위로 찍는 쪽은 매번 없는 값에 걸려 아무 흔적도 없이 계속
 * 시도할 수 있다. 여섯 글자는 30자로 7억 가지라 이 한도가 사실상 추측을 막는 유일한 장치다.
 *
 * <p>입력은 성공·실패 가리지 않고 센다. 사람이 코드를 받아적는 일은 10분에 한두 번이다. 한도에 닿으면 계정을 바꿔
 * 이어 갈 수 있지만, 계정마다 가입·약관 동의가 필요하다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProfileInviteRateLimiter {

  // 한도: 설정 PROFILE_INVITE_REDEEM/ISSUE_LIMIT_PER_10_MINUTES (기본 10번씩)
  // 창 길이: 위 키 이름의 "10분"과 함께 바꾼다
  static final Duration WINDOW = Duration.ofMinutes(10);

  private static final String REDEEM_PREFIX = "profile-invite-redeem:";
  private static final String ISSUE_PREFIX = "profile-invite-issue:";

  private final SharedStateStore sharedStateStore;
  private final UsageLimitSettings usageLimitSettings;

  /** 코드를 넣어 봐도 되면 true. 창 안에서 한도를 넘었으면 false. */
  public boolean tryRedeem(String memberId) {
    boolean allowed = sharedStateStore.tryRecordInWindow(
      REDEEM_PREFIX + memberId, WINDOW, usageLimitSettings.profileInviteRedeemLimitPerTenMinutes(),
      System.currentTimeMillis());
    if (!allowed) {
      log.warn("초대 코드 입력이 너무 잦습니다: memberId={}", memberId);
    }
    return allowed;
  }

  /** 코드를 새로 내도 되면 true. */
  public boolean tryIssue(String memberId) {
    boolean allowed = sharedStateStore.tryRecordInWindow(
      ISSUE_PREFIX + memberId, WINDOW, usageLimitSettings.profileInviteIssueLimitPerTenMinutes(),
      System.currentTimeMillis());
    if (!allowed) {
      log.warn("초대 코드 발급이 너무 잦습니다: memberId={}", memberId);
    }
    return allowed;
  }
}
