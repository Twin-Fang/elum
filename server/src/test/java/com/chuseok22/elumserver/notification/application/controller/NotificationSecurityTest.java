package com.chuseok22.elumserver.notification.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.notification.application.service.NotificationSettingService;
import com.chuseok22.elumserver.notification.application.service.PushDeviceService;
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

/// 알림 API 의 문 앞: 토큰이 없으면 401, 이룸이 권한이면 403, 보호자만 통과한다. (알림 목록은 Task 6 이 더한다)
@WebMvcTest(controllers = {PushDeviceController.class, NotificationSettingController.class})
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class NotificationSecurityTest {

  private static final SimpleGrantedAuthority MEMBER = new SimpleGrantedAuthority("ROLE_MEMBER");
  private static final SimpleGrantedAuthority GUARDIAN = new SimpleGrantedAuthority("ROLE_GUARDIAN");
  private static final SimpleGrantedAuthority ELUMI = new SimpleGrantedAuthority("ROLE_ELUMI");
  private static final String DEVICE_BODY = "{\"token\":\"fcm-token\",\"platform\":\"IOS\"}";

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private PushDeviceService pushDeviceService;
  @MockitoBean
  private NotificationSettingService notificationSettingService;

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
  void noToken_401() throws Exception {
    mockMvc.perform(put("/api/push-devices").contentType(MediaType.APPLICATION_JSON).content(DEVICE_BODY))
      .andExpect(status().isUnauthorized());

    verify(pushDeviceService, never()).register(anyString(), any());
  }

  @Test
  @DisplayName("이룸이 기기 권한으로는 기기를 등록할 수 없다")
  void elumiToken_registerDevice_403() throws Exception {
    mockMvc.perform(put("/api/push-devices").with(user("e1").authorities(MEMBER, ELUMI))
        .contentType(MediaType.APPLICATION_JSON).content(DEVICE_BODY))
      .andExpect(status().isForbidden());

    verify(pushDeviceService, never()).register(anyString(), any());
  }

  @Test
  @DisplayName("보호자는 기기를 등록하고 204 를 받는다")
  void guardianToken_registerDevice_204() throws Exception {
    mockMvc.perform(put("/api/push-devices").with(user("g1").authorities(MEMBER, GUARDIAN))
        .contentType(MediaType.APPLICATION_JSON).content(DEVICE_BODY))
      .andExpect(status().isNoContent());

    verify(pushDeviceService).register(anyString(), any());
  }
}
