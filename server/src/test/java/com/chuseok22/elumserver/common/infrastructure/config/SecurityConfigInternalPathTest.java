package com.chuseok22.elumserver.common.infrastructure.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.member.application.controller.MemberController;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.member.application.service.OnboardingService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.mapping.JpaMetamodelMappingContext;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * API 보안 체인이 내부 경로 {@code /api/internal/**} 를 막는지 본다 (이슈 #382).
 *
 * <p>체인 마지막 규칙이 {@code anyRequest().hasAuthority(GUARDIAN)} 이라, 따로 막지 않으면
 * 따로 막지 않으면 가입만 한 누구나 내부 경로를 부를 수 있다(과거 운영 실측 200).
 * 대조군으로 같은 {@code anyRequest} 규칙을 타는 보호자 API 가 여전히 열려 있는지도 본다 —
 * 체인을 통째로 막아 버려도 첫 테스트는 통과하기 때문이다.
 *
 * <p>JWT 를 실제로 만들지 않고 {@code user()} 로 인증을 심는다. 보려는 것은 토큰 해석이 아니라
 * 인가 규칙이고, JwtAuthenticationFilter 는 헤더가 없으면 심어 둔 인증을 건드리지 않는다.
 */
@WebMvcTest(controllers = {SecurityConfigInternalPathTest.InternalProbeController.class, MemberController.class})
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class, SecurityConfigInternalPathTest.InternalProbeController.class})
class SecurityConfigInternalPathTest {

  // 실제 내부 엔드포인트는 없다 — /api/internal/** 규칙만 보는 시험용 경로
  static final String INTERNAL_PROBE_PATH = "/api/internal/probe";
  private static final String BODY = "{\"text\":\"hello\"}";

  @Autowired
  private MockMvc mockMvc;

  // /api/internal/** 규칙만 보려는 시험용 컨트롤러 — 막혔다면 한 번도 불리지 않아야 한다
  private static final AtomicInteger INTERNAL_PROBE_CALL_COUNT = new AtomicInteger();

  @RestController
  static class InternalProbeController {
    @PostMapping(INTERNAL_PROBE_PATH)
    String probe() {
      INTERNAL_PROBE_CALL_COUNT.incrementAndGet();
      return "ok";
    }
  }

  @BeforeEach
  void resetInternalProbeCallCount() {
    INTERNAL_PROBE_CALL_COUNT.set(0);
  }

  @MockitoBean
  private MemberService memberService;
  @MockitoBean
  private OnboardingService onboardingService;

  // SecurityConfig 생성자가 요구하는 빈들
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
  @DisplayName("보호자 토큰으로 내부 경로를 부르면 403 이고 컨트롤러는 실행되지 않는다")
  void guardian_isForbidden_onInternalPath() throws Exception {
    mockMvc.perform(post(INTERNAL_PROBE_PATH)
        .with(user("guardian-1").authorities(
          new SimpleGrantedAuthority("ROLE_MEMBER"),
          new SimpleGrantedAuthority("ROLE_GUARDIAN")))
        .contentType(MediaType.APPLICATION_JSON)
        .content(BODY))
      .andExpect(status().isForbidden());

    assertThat(INTERNAL_PROBE_CALL_COUNT.get()).isZero();
  }

  @Test
  @DisplayName("토큰 없이 부르면 여전히 401 이다")
  void anonymous_isUnauthorized_onInternalPath() throws Exception {
    mockMvc.perform(post(INTERNAL_PROBE_PATH)
        .contentType(MediaType.APPLICATION_JSON)
        .content(BODY))
      .andExpect(status().isUnauthorized());

    assertThat(INTERNAL_PROBE_CALL_COUNT.get()).isZero();
  }

  @Test
  @DisplayName("대조군 — 같은 anyRequest 규칙을 타는 보호자 API 는 그대로 열려 있다")
  void guardian_canStillReachGuardianApi() throws Exception {
    // GET /api/member/consents 는 명시 허용 목록에 없어 anyRequest().hasAuthority(GUARDIAN) 로 떨어진다
    mockMvc.perform(get("/api/member/consents")
        .with(user("guardian-1").authorities(
          new SimpleGrantedAuthority("ROLE_MEMBER"),
          new SimpleGrantedAuthority("ROLE_GUARDIAN"))))
      .andExpect(status().isOk());
  }
}
