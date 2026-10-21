package com.chuseok22.elumserver.systemconfig.application.service;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Duration;
import java.util.Map;
import java.util.function.ToIntFunction;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 사용 한도·남용 방지 설정 읽기: 일과 요청 간격, 카드 그림·의견·초대·연결 암호 한도, 음성 합성 동시 수·실패 쉬는 시간
 * 요청마다 설정 캐시(30초)에서 읽음 > 관리자 화면에서 바꾸면 재시작 없이 다음 요청부터 반영
 */
@Component
public class UsageLimitSettings {

  // 키 > 정수 값 (운영: SystemConfigService.getInt, 범위 밖 저장값은 기본값으로 대신함)
  private final ToIntFunction<ConfigKey> integerReader;

  @Autowired
  public UsageLimitSettings(SystemConfigService systemConfigService) {
    this(systemConfigService::getInt);
  }

  private UsageLimitSettings(ToIntFunction<ConfigKey> integerReader) {
    this.integerReader = integerReader;
  }

  /// 저장값 없이 키 기본값만 읽음 (시험·DB 없이 조립할 때)
  public static UsageLimitSettings fromDefaults() {
    return fromValues(Map.of());
  }

  /// 일부 키만 고정 값, 나머지는 키 기본값 (시험용)
  public static UsageLimitSettings fromValues(Map<ConfigKey, Integer> valueByKey) {
    return new UsageLimitSettings(key -> valueByKey.getOrDefault(key, Integer.parseInt(key.getDefaultValue())));
  }

  public Duration routineRequestCooldown() {
    return Duration.ofSeconds(integerReader.applyAsInt(ConfigKey.ROUTINE_REQUEST_COOLDOWN_SECONDS));
  }

  /// 회원별 카드 그림 한도 (10분 창)
  public int routineStepImageLimitPerTenMinutes() {
    return integerReader.applyAsInt(ConfigKey.ROUTINE_STEP_IMAGE_LIMIT_PER_10_MINUTES);
  }

  public int feedbackDailyLimit() {
    return integerReader.applyAsInt(ConfigKey.FEEDBACK_DAILY_LIMIT);
  }

  /// 계정별 초대 코드 발급 한도 (10분 창)
  public int profileInviteIssueLimitPerTenMinutes() {
    return integerReader.applyAsInt(ConfigKey.PROFILE_INVITE_ISSUE_LIMIT_PER_10_MINUTES);
  }

  /// 계정별 초대 코드 입력 한도 (10분 창)
  public int profileInviteRedeemLimitPerTenMinutes() {
    return integerReader.applyAsInt(ConfigKey.PROFILE_INVITE_REDEEM_LIMIT_PER_10_MINUTES);
  }

  /// 호출자별 연결 암호 입력 한도 (1분 창)
  public int linkRedeemLimitPerMinute() {
    return integerReader.applyAsInt(ConfigKey.LINK_REDEEM_LIMIT_PER_MINUTE);
  }

  public int ttsOnDemandMaxConcurrent() {
    return integerReader.applyAsInt(ConfigKey.TTS_ON_DEMAND_MAX_CONCURRENT);
  }

  public Duration ttsFailureCooldown() {
    return Duration.ofMinutes(integerReader.applyAsInt(ConfigKey.TTS_FAILURE_COOLDOWN_MINUTES));
  }
}
