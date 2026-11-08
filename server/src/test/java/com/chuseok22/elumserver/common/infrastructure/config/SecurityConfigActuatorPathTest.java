package com.chuseok22.elumserver.common.infrastructure.config;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.application.controller.HealthController;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.actuate.autoconfigure.endpoint.EndpointAutoConfiguration;
import org.springframework.boot.actuate.autoconfigure.endpoint.web.WebEndpointAutoConfiguration;
import org.springframework.boot.actuate.autoconfigure.web.server.ManagementContextAutoConfiguration;
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.micrometer.metrics.autoconfigure.CompositeMeterRegistryAutoConfiguration;
import org.springframework.boot.micrometer.metrics.autoconfigure.MetricsAutoConfiguration;
import org.springframework.boot.micrometer.metrics.autoconfigure.export.prometheus.PrometheusMetricsExportAutoConfiguration;
import org.springframework.boot.micrometer.metrics.autoconfigure.jvm.JvmMetricsAutoConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.mapping.JpaMetamodelMappingContext;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * actuator 체인 (#1222): 실제 /actuator/prometheus 를 서블릿 필터 켠 채로 부름
 * 확인 5개: 토큰 없음 401, 틀린 토큰 401, 맞는 토큰 200 + JVM 지표, health 비노출, /healthz 그대로 200
 *
 * <p>웹 슬라이스에 actuator 가 없어 지표·엔드포인트 자동 설정만 골라 더함 (DB 없이 뜨게)
 */
@WebMvcTest(controllers = HealthController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
@ImportAutoConfiguration({
  EndpointAutoConfiguration.class,
  WebEndpointAutoConfiguration.class,
  ManagementContextAutoConfiguration.class,
  MetricsAutoConfiguration.class,
  CompositeMeterRegistryAutoConfiguration.class,
  PrometheusMetricsExportAutoConfiguration.class,
  JvmMetricsAutoConfiguration.class
})
@TestPropertySource(properties = {
  "elum.metrics.scrape-token=" + SecurityConfigActuatorPathTest.SCRAPE_TOKEN,
  // 테스트 컨텍스트가 지표 내보내기를 끄는 경우에도 prometheus 는 켬
  "management.prometheus.metrics.export.enabled=true"
})
class SecurityConfigActuatorPathTest {

  static final String SCRAPE_TOKEN = "test-scrape-token-1222";
  private static final String PROMETHEUS_PATH = "/actuator/prometheus";
  // JvmMetrics 가 등록하는 대표 지표 (응답 본문에 실제 수집 결과가 있는지)
  private static final String JVM_MEMORY_METRIC_NAME = "jvm_memory_used_bytes";

  @Autowired
  private MockMvc mockMvc;

  // SecurityConfig 생성자가 요구하는 빈들 (SecurityConfigInternalPathTest 와 같은 조합)
  @MockitoBean(name = "memberUserDetailsService")
  private UserDetailsService memberUserDetailsService;
  @MockitoBean(name = "adminUserDetailsService")
  private UserDetailsService adminUserDetailsService;
  @MockitoBean
  private JwtProvider jwtProvider;
  @MockitoBean
  private TokenAccessValidator tokenAccessValidator;
  @MockitoBean
  private LinkAccessValidator linkAccessValidator;
  @MockitoBean
  private SystemConfigService systemConfigService;
  @MockitoBean
  private SharedStateStore sharedStateStore;

  // 메인 클래스의 @EnableJpaAuditing 이 웹 슬라이스에서도 JPA 메타모델을 찾는다
  @MockitoBean
  private JpaMetamodelMappingContext jpaMetamodelMappingContext;

  @Test
  @DisplayName("토큰 없이 지표를 부르면 401 이고 지표는 나가지 않는다")
  void prometheus_withoutToken_isUnauthorized() throws Exception {
    mockMvc.perform(get(PROMETHEUS_PATH))
      .andExpect(status().isUnauthorized())
      .andExpect(content().string(not(containsString(JVM_MEMORY_METRIC_NAME))));
  }

  @Test
  @DisplayName("틀린 토큰으로 지표를 부르면 401 이다")
  void prometheus_withWrongToken_isUnauthorized() throws Exception {
    mockMvc.perform(get(PROMETHEUS_PATH).header(HttpHeaders.AUTHORIZATION, "Bearer wrong-token"))
      .andExpect(status().isUnauthorized())
      .andExpect(content().string(not(containsString(JVM_MEMORY_METRIC_NAME))));
  }

  @Test
  @DisplayName("맞는 토큰으로 지표를 부르면 200 이고 JVM 지표가 들어 있다")
  void prometheus_withScrapeToken_returnsMetrics() throws Exception {
    mockMvc.perform(get(PROMETHEUS_PATH).header(HttpHeaders.AUTHORIZATION, "Bearer " + SCRAPE_TOKEN))
      .andExpect(status().isOk())
      .andExpect(content().string(containsString(JVM_MEMORY_METRIC_NAME)))
      .andExpect(content().string(containsString("application=\"elum-server\"")));
  }

  @Test
  @DisplayName("health 는 웹에 열지 않는다 — 토큰 없이 401, 맞는 토큰이어도 403")
  void health_isNotExposed() throws Exception {
    mockMvc.perform(get("/actuator/health"))
      .andExpect(status().isUnauthorized());
    mockMvc.perform(get("/actuator/health").header(HttpHeaders.AUTHORIZATION, "Bearer " + SCRAPE_TOKEN))
      .andExpect(status().isForbidden());
  }

  @Test
  @DisplayName("actuator 목록 주소도 맞는 토큰으로 403 이다")
  void actuatorRoot_isDenied() throws Exception {
    mockMvc.perform(get("/actuator").header(HttpHeaders.AUTHORIZATION, "Bearer " + SCRAPE_TOKEN))
      .andExpect(status().isForbidden());
  }

  @Test
  @DisplayName("대조군 — 컨테이너 헬스체크 /healthz 는 인증 없이 그대로 200 이다")
  void healthz_isStillOpen() throws Exception {
    mockMvc.perform(get("/healthz"))
      .andExpect(status().isOk())
      .andExpect(content().string(containsString("UP")));
  }
}
