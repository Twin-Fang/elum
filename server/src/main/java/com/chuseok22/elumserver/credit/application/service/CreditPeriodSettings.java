package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.core.CreditPeriodUnit;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 크레딧 지급 주기 설정: 단위(WEEK·MONTH) 읽기, 지금의 주기 계산
 * 값이 비었거나 모르는 값이면 WEEK — 지금까지와 같은 동작
 */
@Component
@RequiredArgsConstructor
public class CreditPeriodSettings {

  private final SystemConfigService config;

  public CreditPeriodUnit unit() {
    return CreditPeriodUnit.fromConfigValue(config.getString(ConfigKey.CREDIT_PERIOD_UNIT));
  }

  /// 설정 단위 기준으로 now 가 든 주기
  public CreditPeriod periodContaining(LocalDateTime now) {
    return CreditPeriod.of(unit(), now);
  }
}
