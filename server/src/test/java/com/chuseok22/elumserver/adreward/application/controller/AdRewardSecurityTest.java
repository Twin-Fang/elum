package com.chuseok22.elumserver.adreward.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.adreward.application.service.AdRewardGrantService;
import com.chuseok22.elumserver.adreward.application.service.AdRewardOffer;
import com.chuseok22.elumserver.adreward.application.service.AdRewardResult;
import com.chuseok22.elumserver.adreward.application.service.AdRewardSessionInfo;
import com.chuseok22.elumserver.adreward.application.service.AdRewardSessionService;
import com.chuseok22.elumserver.adreward.application.service.SsvCallback;
import com.chuseok22.elumserver.adreward.application.service.SsvCallbackVerifier;
import com.chuseok22.elumserver.adreward.application.service.SsvInvalidException;
import com.chuseok22.elumserver.adreward.application.service.SsvKeysUnavailableException;
import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.mapping.JpaMetamodelMappingContext;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 광고 보상 API 의 **문 앞** (#463): 누가 들어올 수 있는가, Google 콜백은 어떤 코드로 답하는가.
 *
 * <p>콜백이 인증 없이 열려 있는 만큼, 서명이 틀리면 반드시 막히고(400) 지급 서비스는 한 번도 불리지 않아야 한다. 반대로
 * 보호자 API 는 토큰이 있어야 하고, 이룸이 휴대폰(ELUMI)은 부를 수 없어야 한다 — 광고는 보호자 화면에만 있다.
 */
@WebMvcTest(controllers = {AdRewardController.class, AdSsvCallbackController.class})
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class AdRewardSecurityTest {

  private static final SimpleGrantedAuthority MEMBER = new SimpleGrantedAuthority("ROLE_MEMBER");
  private static final SimpleGrantedAuthority GUARDIAN = new SimpleGrantedAuthority("ROLE_GUARDIAN");
  private static final SimpleGrantedAuthority ELUMI = new SimpleGrantedAuthority("ROLE_ELUMI");

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private AdRewardSessionService sessionService;
  @MockitoBean
  private SsvCallbackVerifier verifier;
  @MockitoBean
  private AdRewardGrantService grantService;

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

  // --- Google 콜백: 인증 없이 열려 있다 (서명이 인증) ---

  @Test
  @DisplayName("콜백은 토큰 없이도 닿고, 서명이 유효하면 지급하고 200 ok 로 답한다")
  void ssv_validSignature_grantsAndReturnsOk() throws Exception {
    SsvCallback callback = new SsvCallback("6517734434", "nonce-1", "tx-1", "m1");
    when(verifier.verify(anyString())).thenReturn(callback);
    when(grantService.grant(callback)).thenReturn(AdRewardResult.granted());

    mockMvc.perform(get("/api/ads/ssv?ad_unit=6517734434&custom_data=nonce-1&signature=x&key_id=1"))
      .andExpect(status().isOk())
      .andExpect(content().string("ok"));

    verify(grantService, times(1)).grant(callback);
  }

  @Test
  @DisplayName("서명이 틀리면 400 이고 지급 서비스는 한 번도 불리지 않는다")
  void ssv_invalidSignature_returns400AndNeverGrants() throws Exception {
    when(verifier.verify(any())).thenThrow(new SsvInvalidException("서명이 맞지 않다"));

    mockMvc.perform(get("/api/ads/ssv?custom_data=nonce-1&signature=bad&key_id=1"))
      .andExpect(status().isBadRequest());

    verify(grantService, never()).grant(any());
  }

  @Test
  @DisplayName("쿼리가 아예 없어도 400 이다(null 쿼리로 죽지 않는다)")
  void ssv_noQuery_returns400() throws Exception {
    when(verifier.verify(any())).thenThrow(new SsvInvalidException("쿼리가 비었다"));

    mockMvc.perform(get("/api/ads/ssv")).andExpect(status().isBadRequest());

    verify(grantService, never()).grant(any());
  }

  @Test
  @DisplayName("공개키를 못 구하면 503 으로 답해 Google 이 다시 보내게 하고, 지급하지 않는다")
  void ssv_keysUnavailable_returns503() throws Exception {
    when(verifier.verify(any())).thenThrow(new SsvKeysUnavailableException("키를 받지 못했다"));

    mockMvc.perform(get("/api/ads/ssv?custom_data=nonce-1&signature=x&key_id=1"))
      .andExpect(status().isServiceUnavailable());

    verify(grantService, never()).grant(any());
  }

  @Test
  @DisplayName("서명이 맞으면 결과가 거절이어도 200 이다(Google 이 의미 없이 다시 보내지 않는다)")
  void ssv_businessRejection_stillReturns200() throws Exception {
    SsvCallback callback = new SsvCallback("6517734434", "nonce-1", "tx-1", "m1");
    when(verifier.verify(any())).thenReturn(callback);
    when(grantService.grant(callback)).thenReturn(AdRewardResult.duplicate());

    mockMvc.perform(get("/api/ads/ssv?custom_data=nonce-1&signature=x&key_id=1"))
      .andExpect(status().isOk());
  }

  // --- 보호자 API: 토큰과 보호자 권한이 필요하다 ---

  @Test
  @DisplayName("토큰 없이 보호자 API 를 부르면 401 이다")
  void memberApis_withoutToken_are401() throws Exception {
    mockMvc.perform(get("/api/credits/ad-rewards/offer")).andExpect(status().isUnauthorized());
    mockMvc.perform(post("/api/credits/ad-rewards/sessions")).andExpect(status().isUnauthorized());
    mockMvc.perform(get("/api/credits/ad-rewards/sessions/abc")).andExpect(status().isUnauthorized());

    verify(sessionService, never()).create(anyString());
  }

  @Test
  @DisplayName("이룸이 휴대폰 권한으로는 부를 수 없다 — 광고는 보호자 화면에만 있다")
  void memberApis_asElumi_are403() throws Exception {
    mockMvc.perform(get("/api/credits/ad-rewards/offer").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());
    mockMvc.perform(post("/api/credits/ad-rewards/sessions").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());

    verify(sessionService, never()).create(anyString());
  }

  @Test
  @DisplayName("보호자는 제안을 받고 세션을 만들 수 있다")
  void memberApis_asGuardian_work() throws Exception {
    when(sessionService.offer("g1")).thenReturn(new AdRewardOffer(true, 2, 5));
    when(sessionService.create("g1"))
      .thenReturn(new AdRewardSessionInfo("nonce-xyz", LocalDateTime.of(2026, 9, 30, 15, 30), 2, 5));

    mockMvc.perform(get("/api/credits/ad-rewards/offer").with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.enabled").value(true))
      .andExpect(jsonPath("$.creditsPerView").value(2))
      .andExpect(jsonPath("$.remainingToday").value(5));

    mockMvc.perform(post("/api/credits/ad-rewards/sessions").with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.nonce").value("nonce-xyz"))
      .andExpect(jsonPath("$.creditsPerView").value(2));

    verify(sessionService).create(eq("g1"));
  }
}
