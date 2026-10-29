package com.chuseok22.elumserver.common.infrastructure.alert;

import com.chuseok22.elumserver.common.application.alert.IncidentAlertService;
import com.chuseok22.elumserver.common.application.alert.ServerErrorSurgeDetector;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;

/**
 * 5xx 급증 필터 등록: RequestIdFilter(가장 앞) 바로 다음 > 보안 필터에서 난 오류까지 셈 (#648)
 */
@Configuration
public class IncidentAlertFilterConfig {

  // RequestIdFilter(HIGHEST_PRECEDENCE) 다음
  private static final int SERVER_ERROR_SURGE_FILTER_ORDER = Ordered.HIGHEST_PRECEDENCE + 1;

  @Bean
  public FilterRegistrationBean<ServerErrorSurgeFilter> serverErrorSurgeFilterRegistration(
    ServerErrorSurgeDetector serverErrorSurgeDetector, IncidentAlertService incidentAlertService
  ) {
    FilterRegistrationBean<ServerErrorSurgeFilter> registration = new FilterRegistrationBean<>(
      new ServerErrorSurgeFilter(serverErrorSurgeDetector, incidentAlertService));
    registration.setOrder(SERVER_ERROR_SURGE_FILTER_ORDER);
    return registration;
  }
}
