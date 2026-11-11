package com.chuseok22.elumserver.admin.application.controller;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionResponse;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionSource;
import com.chuseok22.elumserver.admin.application.service.ControlTowerAttentionService;
import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.mapping.JpaMetamodelMappingContext;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/// /control/attention 은 관리자 로그인·JWT 체인 밖: 로그인 없이 컨트롤러까지 오고 인증은 X-Control-Token 만 (#1229)
@WebMvcTest(controllers = ControlTowerAttentionController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class ControlTowerAttentionSecurityTest {

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private ControlTowerAttentionService controlTowerAttentionService;

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
  @MockitoBean
  private JpaMetamodelMappingContext jpaMetamodelMappingContext;

  @Test
  @DisplayName("세션·JWT 없이 맞는 토큰이면 200 (로그인 화면으로 보내거나 JWT 401 을 주지 않는다)")
  void withoutLogin_validToken_reachesController() throws Exception {
    when(controlTowerAttentionService.isEnabled()).thenReturn(true);
    when(controlTowerAttentionService.isTokenAccepted("valid-token")).thenReturn(true);
    when(controlTowerAttentionService.buildSnapshot()).thenReturn(ControlTowerAttentionResponse.of(
      new ControlTowerAttentionSource("elum-server", null, "development", null), "2026-11-08T00:00:00Z", List.of()));

    mockMvc.perform(get("/control/attention").header("X-Control-Token", "valid-token"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.schema").value("attention"));
  }

  @Test
  @DisplayName("세션·JWT 없이 토큰도 없으면 컨트롤러의 401 (체인 리다이렉트 아님)")
  void withoutLogin_withoutToken_isControllerUnauthorized() throws Exception {
    when(controlTowerAttentionService.isEnabled()).thenReturn(true);

    mockMvc.perform(get("/control/attention")).andExpect(status().isUnauthorized());
  }
}
