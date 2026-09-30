package com.chuseok22.elumserver.adreward.application.service;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Duration;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 광고 보상 설정을 안전한 쪽으로 읽는다 (#463).
 *
 * <p>값이 이상하면(0 이하·비정수) **주지 않는 쪽**으로 읽는다. 관리자 화면이 범위를 막지만, DB 를 직접 만졌거나
 * 저장된 값이 손상돼도 크레딧이 새지 않게 한 번 더 막는다.
 */
@Component
@RequiredArgsConstructor
public class AdRewardSettings {

  private final SystemConfigService config;

  /// 켜져 있고 지급량·상한이 모두 양수일 때만 켜진 것으로 본다.
  public boolean enabled() {
    return config.getBoolean(ConfigKey.AD_REWARD_ENABLED) && creditsPerView() > 0 && dailyLimit() > 0;
  }

  public int creditsPerView() {
    return Math.max(0, config.getInt(ConfigKey.AD_REWARD_CREDITS_PER_VIEW));
  }

  public int dailyLimit() {
    return Math.max(0, config.getInt(ConfigKey.AD_REWARD_DAILY_LIMIT));
  }

  public Duration sessionTtl() {
    return Duration.ofMinutes(Math.max(1, config.getInt(ConfigKey.AD_REWARD_SESSION_TTL_MINUTES)));
  }

  /// 허용 목록은 전체 ID 든 숫자든 뒤의 숫자로 비교한다. 목록이 비면 아무것도 허용하지 않는다.
  public boolean isAllowedAdUnit(String adUnit) {
    if (adUnit == null || adUnit.isBlank()) {
      return false;
    }
    Set<String> allowed = Arrays.stream(config.getString(ConfigKey.AD_REWARD_ALLOWED_AD_UNITS).split(","))
      .map(SsvCallbackVerifier::normalizeAdUnit)
      .filter(unit -> !unit.isEmpty())
      .collect(Collectors.toSet());
    return allowed.contains(SsvCallbackVerifier.normalizeAdUnit(adUnit));
  }
}
