package com.chuseok22.elumserver.notification.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.notification.application.service.NotificationQueryService;
import com.chuseok22.elumserver.notification.application.service.NotificationReadService;
import com.chuseok22.elumserver.notification.application.service.NotificationSettingService;
import com.chuseok22.elumserver.notification.application.service.PushDeviceService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
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

/// 알림 API 의 문 앞: 토큰이 없으면 401, 이룸이 권한이면 403, 보호자만 통과한다.
@WebMvcTest(controllers = {PushDeviceController.class, NotificationSettingController.class, NotificationController.class})
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
  @MockitoBean
  private NotificationQueryService notificationQueryService;
  @MockitoBean
  private NotificationReadService notificationReadService;

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

  @Test
  @DisplayName("이룸이 기기 권한으로는 알림 목록을 볼 수 없다")
  void elumiToken_getNotifications_403() throws Exception {
    mockMvc.perform(get("/api/notifications").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());

    verify(notificationQueryService, never()).page(anyString(), any(), any());
  }

  @Test
  @DisplayName("이룸이 기기 권한으로는 안 읽음 요약을 볼 수 없다")
  void elumiToken_unreadSummary_403() throws Exception {
    mockMvc.perform(get("/api/notifications/unread-summary").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());

    verify(notificationQueryService, never()).unreadSummary(anyString(), any());
  }

  @Test
  @DisplayName("보호자는 알림을 읽음 처리하고 204 를 받는다")
  void guardianToken_markRead_204() throws Exception {
    mockMvc.perform(post("/api/notifications/n1/read").with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isNoContent());

    verify(notificationReadService).markRead(eq("g1"), eq("n1"));
  }

  @Test
  @DisplayName("이룸이 기기 권한으로는 푸시 기기를 해제할 수 없다")
  void elumiToken_unregisterDevice_403() throws Exception {
    mockMvc.perform(delete("/api/push-devices/fcm-token").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());

    verify(pushDeviceService, never()).unregister(anyString(), anyString());
  }

  @Test
  @DisplayName("이룸이 기기 권한으로는 알림 설정을 볼 수 없다")
  void elumiToken_getNotificationSettings_403() throws Exception {
    mockMvc.perform(get("/api/notification-settings").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());

    verify(notificationSettingService, never()).get(anyString());
  }

  @Test
  @DisplayName("이룸이 기기 권한으로는 알림 설정을 바꿀 수 없다")
  void elumiToken_updateNotificationSettings_403() throws Exception {
    mockMvc.perform(put("/api/notification-settings").with(user("e1").authorities(MEMBER, ELUMI))
        .contentType(MediaType.APPLICATION_JSON).content("{}"))
      .andExpect(status().isForbidden());

    verify(notificationSettingService, never()).update(anyString(), any());
  }
}
