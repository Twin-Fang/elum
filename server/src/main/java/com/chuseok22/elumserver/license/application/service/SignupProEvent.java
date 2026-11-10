package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.member.application.service.MemberSignupTimeService;
import com.chuseok22.elumserver.systemconfig.application.service.ConfigDateTime;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDateTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 신규가입 Pro 체험 판정: 켜짐 > 가입 기간 [시작, 종료] 읽기 > 가입 시각이 기간 안 > 지금 < 가입 시각 + 유지 일수
 * 조회 시점 계산 (DB 쓰기 없음, 꺼져 있으면 조회 없음). 설정·조회 오류는 체험 없음으로 (Free 쪽으로 기울임)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SignupProEvent {

  private final SystemConfigService systemConfigService;
  private final MemberSignupTimeService memberSignupTimeService;

  /// 체험 대상이면 Pro 종료 시각(가입 시각 + 유지 일수), 아니면 빈 값 (구독 행 우선 판단은 부르는 쪽)
  public Optional<LocalDateTime> trialEndsAt(String memberId) {
    if (memberId == null || memberId.isBlank() || !systemConfigService.getBoolean(ConfigKey.SIGNUP_PRO_EVENT_ENABLED)) {
      return Optional.empty();
    }
    try {
      String startAtText = systemConfigService.getString(ConfigKey.SIGNUP_PRO_EVENT_START_AT);
      String endAtText = systemConfigService.getString(ConfigKey.SIGNUP_PRO_EVENT_END_AT);
      // 가입 기간이 비어 있으면 이벤트 꺼짐
      if (startAtText == null || startAtText.isBlank() || endAtText == null || endAtText.isBlank()) {
        return Optional.empty();
      }
      LocalDateTime signupWindowStart = ConfigDateTime.parse(startAtText);
      LocalDateTime signupWindowEnd = ConfigDateTime.parse(endAtText);
      int grantDays = systemConfigService.getInt(ConfigKey.SIGNUP_PRO_EVENT_GRANT_DAYS);
      return memberSignupTimeService.findSignupAt(memberId)
        .filter(signupAt -> !signupAt.isBefore(signupWindowStart) && !signupAt.isAfter(signupWindowEnd))
        .map(signupAt -> signupAt.plusDays(grantDays))
        .filter(trialEndsAt -> LocalDateTime.now().isBefore(trialEndsAt));
    } catch (Exception e) {
      log.warn("[signup pro event] evaluation failed, no trial : memberId={}", memberId, e);
      return Optional.empty();
    }
  }
}
