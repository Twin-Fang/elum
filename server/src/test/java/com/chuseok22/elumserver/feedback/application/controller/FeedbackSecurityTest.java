package com.chuseok22.elumserver.feedback.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
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

/// 의견 보내기 API 의 문 앞: 토큰이 없으면 401, 이룸이 권한이면 403, 보호자만 통과한다.
@WebMvcTest(controllers = FeedbackController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class FeedbackSecurityTest {

  private static final SimpleGrantedAuthority MEMBER = new SimpleGrantedAuthority("ROLE_MEMBER");
  private static final SimpleGrantedAuthority GUARDIAN = new SimpleGrantedAuthority("ROLE_GUARDIAN");
  private static final SimpleGrantedAuthority ELUMI = new SimpleGrantedAuthority("ROLE_ELUMI");
  private static final String BODY = "{\"message\":\"느려요\"}";

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private FeedbackService feedbackService;

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
  private AidlpCryptoService aidlpCryptoService;
  @MockitoBean
  private NonceStore nonceStore;
  @MockitoBean
  private AidlpProperties aidlpProperties;
  @MockitoBean
  private JpaMetamodelMappingContext jpaMetamodelMappingContext;

  @Test
  @DisplayName("토큰 없이 부르면 401 이다")
  void withoutToken_is401() throws Exception {
    mockMvc.perform(post("/api/feedback").contentType(MediaType.APPLICATION_JSON).content(BODY))
      .andExpect(status().isUnauthorized());

    verify(feedbackService, never()).submit(anyString(), any());
  }

  @Test
  @DisplayName("이룸이 휴대폰 권한으로는 부를 수 없다")
  void asElumi_is403() throws Exception {
    mockMvc.perform(post("/api/feedback").with(user("e1").authorities(MEMBER, ELUMI))
        .contentType(MediaType.APPLICATION_JSON).content(BODY))
      .andExpect(status().isForbidden());

    verify(feedbackService, never()).submit(anyString(), any());
  }

  @Test
  @DisplayName("보호자는 보낼 수 있고 id 를 돌려받는다")
  void asGuardian_works() throws Exception {
    when(feedbackService.submit(anyString(), any())).thenReturn("f1");

    mockMvc.perform(post("/api/feedback").with(user("g1").authorities(MEMBER, GUARDIAN))
        .contentType(MediaType.APPLICATION_JSON).content(BODY))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.id").value("f1"));
  }

  @Test
  @DisplayName("하루 상한을 넘으면 429 로 답한다")
  void rateLimited_is429() throws Exception {
    when(feedbackService.submit(anyString(), any())).thenThrow(new CustomException(ErrorCode.FEEDBACK_RATE_LIMITED));

    mockMvc.perform(post("/api/feedback").with(user("g1").authorities(MEMBER, GUARDIAN))
        .contentType(MediaType.APPLICATION_JSON).content(BODY))
      .andExpect(status().isTooManyRequests());
  }
}
