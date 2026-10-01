package com.chuseok22.elumserver.link.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.jwt.AccessTokenDetails;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.link.application.service.DeviceLinkService;
import com.chuseok22.elumserver.link.application.service.RedeemRateLimiter;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.mapping.JpaMetamodelMappingContext;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 이룸이 휴대폰 연결 끊기의 **문 앞** (#363): 누가 어느 경로로 끊을 수 있는가.
 *
 * <p>같은 계정(`sub`)을 쓰는 두 휴대폰 중 이룸이 휴대폰은 자기 연결만, 보호자는 `linkId` 로 연결을 끊는다.
 * 서비스 안의 판단은 {@code DeviceLinkServiceTest} 가 보고, 여기서는 URL 규칙과 컨트롤러의 역할 검사,
 * 그리고 이룸이 휴대폰의 연결 ID 가 서비스까지 실려 가는지를 본다.
 */
@WebMvcTest(controllers = DeviceLinkController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class DeviceLinkSecurityTest {

  private static final SimpleGrantedAuthority MEMBER = new SimpleGrantedAuthority("ROLE_MEMBER");
  private static final SimpleGrantedAuthority GUARDIAN = new SimpleGrantedAuthority("ROLE_GUARDIAN");
  private static final SimpleGrantedAuthority ELUMI = new SimpleGrantedAuthority("ROLE_ELUMI");

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private DeviceLinkService deviceLinkService;
  @MockitoBean
  private RedeemRateLimiter rateLimiter;

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

  /** 필터가 만드는 것과 같은 모양의 이룸이 휴대폰 인증 — 연결 ID 가 details 에 실린다. */
  private static UsernamePasswordAuthenticationToken elumi(String memberId, String linkId) {
    var auth = UsernamePasswordAuthenticationToken.authenticated(memberId, null, List.of(MEMBER, ELUMI));
    auth.setDetails(new AccessTokenDetails(linkId));
    return auth;
  }

  private static UsernamePasswordAuthenticationToken guardian(String memberId) {
    var auth = UsernamePasswordAuthenticationToken.authenticated(memberId, null, List.of(MEMBER, GUARDIAN));
    auth.setDetails(new AccessTokenDetails(null));
    return auth;
  }

  @Test
  @DisplayName("#363 이룸이 휴대폰은 자기 연결을 끊는다 — 토큰의 연결 ID 가 서비스에 실린다")
  void elumi_revokesOwnLink() throws Exception {
    mockMvc.perform(delete("/api/device-links/current").with(authentication(elumi("m1", "l1"))))
      .andExpect(status().isNoContent());

    ArgumentCaptor<Caller> caller = ArgumentCaptor.forClass(Caller.class);
    verify(deviceLinkService).revokeCurrent(caller.capture());
    org.assertj.core.api.Assertions.assertThat(caller.getValue().linkId()).isEqualTo("l1");
    org.assertj.core.api.Assertions.assertThat(caller.getValue().memberId()).isEqualTo("m1");
  }

  @Test
  @DisplayName("#363 보호자 토큰으로 내 연결 끊기를 부르면 코드가 있는 403 이고 서비스는 불리지 않는다")
  void guardian_cannotUseRevokeCurrent() throws Exception {
    mockMvc.perform(delete("/api/device-links/current").with(authentication(guardian("m1"))))
      .andExpect(status().isForbidden())
      .andExpect(jsonPath("$.errorCode").value("DEVICE_LINK_ONLY_FOR_ELUMI"));

    verify(deviceLinkService, never()).revokeCurrent(any());
  }

  @Test
  @DisplayName("#363 토큰 없이 부르면 401 이다")
  void anonymous_isUnauthorized() throws Exception {
    mockMvc.perform(delete("/api/device-links/current")).andExpect(status().isUnauthorized());

    verify(deviceLinkService, never()).revokeCurrent(any());
  }

  @Test
  @DisplayName("#363 이룸이 휴대폰은 linkId 로 다른 연결을 끊지 못한다 — 자기 것은 /current 로만")
  void elumi_cannotRevokeByLinkId() throws Exception {
    // URL 규칙(anyRequest = 보호자)이 컨트롤러에 닿기 전에 막는다
    mockMvc.perform(delete("/api/device-links/l2").with(authentication(elumi("m1", "l1"))))
      .andExpect(status().isForbidden());

    verify(deviceLinkService, never()).revoke(anyString(), anyString());
  }

  @Test
  @DisplayName("#363 보호자는 linkId 로 끊는다 — /current 가 변수 경로에 먹히지 않고 서로 다른 서비스 메서드로 간다")
  void guardian_revokesByLinkId() throws Exception {
    mockMvc.perform(delete("/api/device-links/l2").with(authentication(guardian("m1"))))
      .andExpect(status().isNoContent());

    verify(deviceLinkService).revoke("m1", "l2");
    verify(deviceLinkService, never()).revokeCurrent(any());
  }
}
