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
 * 기존 가입자 Pro 선물 판정: 켜짐 > 기준·종료 시각 읽기 > 가입 시각 < 기준 > 지금 < 종료
 * 조회 시점 계산 (DB 쓰기 없음). 설정·조회 오류는 선물 없음으로 (Free 쪽으로 기울임)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ExistingMemberProGift {

  private final SystemConfigService systemConfigService;
  private final MemberSignupTimeService memberSignupTimeService;

  /// 선물 대상이면 Pro 종료 시각, 아니면 빈 값 (구독 행 우선 판단은 부르는 쪽)
  public Optional<LocalDateTime> giftEndsAt(String memberId) {
    if (memberId == null || memberId.isBlank()
      || !systemConfigService.getBoolean(ConfigKey.EXISTING_MEMBER_PRO_GIFT_ENABLED)) {
      return Optional.empty();
    }
    try {
      String joinedBeforeText = systemConfigService.getString(ConfigKey.EXISTING_MEMBER_PRO_GIFT_JOINED_BEFORE);
      String endsAtText = systemConfigService.getString(ConfigKey.EXISTING_MEMBER_PRO_GIFT_ENDS_AT);
      // 기준·종료가 비어 있으면 선물 꺼짐
      if (joinedBeforeText == null || joinedBeforeText.isBlank() || endsAtText == null || endsAtText.isBlank()) {
        return Optional.empty();
      }
      LocalDateTime joinedBefore = ConfigDateTime.parse(joinedBeforeText);
      LocalDateTime endsAt = ConfigDateTime.parse(endsAtText);
      if (!LocalDateTime.now().isBefore(endsAt)) {
        return Optional.empty();
      }
      return memberSignupTimeService.findSignupAt(memberId)
        .filter(signupAt -> signupAt.isBefore(joinedBefore))
        .map(signupAt -> endsAt);
    } catch (Exception e) {
      log.warn("[existing member pro gift] evaluation failed, no gift : memberId={}", memberId, e);
      return Optional.empty();
    }
  }
}
