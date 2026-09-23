package com.chuseok22.elumserver.common.infrastructure.config;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.ai.application.controller.LocalLlmTestController;
import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.member.application.controller.MemberController;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.mapping.JpaMetamodelMappingContext;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * API 보안 체인이 해커톤 시험용 경로 {@code /api/internal/**} 를 막는지 본다 (이슈 #382).
 *
 * <p>체인 마지막 규칙이 {@code anyRequest().hasAuthority(GUARDIAN)} 이라, 따로 막지 않으면
 * 가입만 하면 누구나 로컬 LLM 을 돌리고 원문을 로그에 남길 수 있었다(운영 실측 200).
 * 대조군으로 같은 {@code anyRequest} 규칙을 타는 보호자 API 가 여전히 열려 있는지도 본다 —
 * 체인을 통째로 막아 버려도 첫 테스트는 통과하기 때문이다.
 *
 * <p>JWT 를 실제로 만들지 않고 {@code user()} 로 인증을 심는다. 보려는 것은 토큰 해석이 아니라
 * 인가 규칙이고, JwtAuthenticationFilter 는 헤더가 없으면 심어 둔 인증을 건드리지 않는다.
 */
@WebMvcTest(controllers = {LocalLlmTestController.class, MemberController.class})
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class SecurityConfigInternalPathTest {

  private static final String SENSITIVE_CHECK = "/api/internal/sensitive-check";
  private static final String BODY = "{\"text\":\"hello\"}";

  @Autowired
  private MockMvc mockMvc;

  // 컨트롤러가 부르는 서비스 — 막혔다면 한 번도 불리지 않아야 한다
  @MockitoBean
  private SensitiveInfoGuardService sensitiveInfoGuardService;
  @MockitoBean
  private MemberService memberService;

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

  // AidlpDecryptionFilter(@Component Filter)는 슬라이스에 자동으로 들어온다. 평문 본문은 그대로 통과시킨다.
  @MockitoBean
  private AidlpCryptoService aidlpCryptoService;
  @MockitoBean
  private NonceStore nonceStore;
  @MockitoBean
  private AidlpProperties aidlpProperties;

  // 메인 클래스의 @EnableJpaAuditing 이 웹 슬라이스에서도 JPA 메타모델을 찾는다
  @MockitoBean
  private JpaMetamodelMappingContext jpaMetamodelMappingContext;

  @Test
  @DisplayName("보호자 토큰으로 민감정보 검사 API 를 부르면 403 이고 로컬 LLM 은 돌지 않는다")
  void guardian_isForbidden_onInternalPath() throws Exception {
    // 막히지 않았을 때 200 이 나오도록 정상 응답을 준비해 둔다 — 그래야 실패가 권한 때문임이 드러난다
    when(sensitiveInfoGuardService.check(any()))
      .thenReturn(new SensitiveInfoCheckResult(true, false, List.of(), "hello"));

    mockMvc.perform(post(SENSITIVE_CHECK)
        .with(user("guardian-1").authorities(
          new SimpleGrantedAuthority("ROLE_MEMBER"),
          new SimpleGrantedAuthority("ROLE_GUARDIAN")))
        .contentType(MediaType.APPLICATION_JSON)
        .content(BODY))
      .andExpect(status().isForbidden());

    verify(sensitiveInfoGuardService, never()).check(any());
  }

  @Test
  @DisplayName("토큰 없이 부르면 여전히 401 이다")
  void anonymous_isUnauthorized_onInternalPath() throws Exception {
    mockMvc.perform(post(SENSITIVE_CHECK)
        .contentType(MediaType.APPLICATION_JSON)
        .content(BODY))
      .andExpect(status().isUnauthorized());

    verify(sensitiveInfoGuardService, never()).check(any());
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
