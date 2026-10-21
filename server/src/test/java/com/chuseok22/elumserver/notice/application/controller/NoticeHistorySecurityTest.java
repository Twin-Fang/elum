package com.chuseok22.elumserver.notice.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.notice.application.service.NoticeHistoryService;
import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryPageResponse;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import java.util.List;
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

/// 공지 탭 API 의 문 앞: 토큰이 없으면 401, 이룸이 권한이면 403, 보호자만 통과한다.
@WebMvcTest(controllers = NoticeHistoryController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class NoticeHistorySecurityTest {

  private static final SimpleGrantedAuthority MEMBER = new SimpleGrantedAuthority("ROLE_MEMBER");
  private static final SimpleGrantedAuthority GUARDIAN = new SimpleGrantedAuthority("ROLE_GUARDIAN");
  private static final SimpleGrantedAuthority ELUMI = new SimpleGrantedAuthority("ROLE_ELUMI");

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private NoticeHistoryService noticeHistoryService;

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
    mockMvc.perform(get("/api/notices/history"))
      .andExpect(status().isUnauthorized());

    verify(noticeHistoryService, never()).history(any(), any(), any());
  }

  @Test
  @DisplayName("이룸이 기기 권한으로는 목록을 부를 수 없다")
  void elumiToken_history_403() throws Exception {
    mockMvc.perform(get("/api/notices/history").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());

    verify(noticeHistoryService, never()).history(any(), any(), any());
  }

  @Test
  @DisplayName("이룸이 기기 권한으로는 읽음을 기록할 수 없다")
  void elumiToken_seen_403() throws Exception {
    mockMvc.perform(post("/api/notices/seen").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());

    verify(noticeHistoryService, never()).markSeen(anyString());
  }

  @Test
  @DisplayName("보호자는 목록을 받는다")
  void guardianToken_history_200() throws Exception {
    when(noticeHistoryService.history(any(), any(), any())).thenReturn(new NoticeHistoryPageResponse(List.of(), null));

    mockMvc.perform(get("/api/notices/history").param("platform", "IOS").with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.items").isEmpty());
  }

  @Test
  @DisplayName("보호자는 읽음을 기록하고 204 를 받는다")
  void guardianToken_seen_204() throws Exception {
    mockMvc.perform(post("/api/notices/seen").with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isNoContent());

    verify(noticeHistoryService).markSeen("g1");
  }
}
