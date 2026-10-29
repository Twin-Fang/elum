package com.chuseok22.elumserver.talk.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.talk.application.dto.response.TalkBlockResponse;
import com.chuseok22.elumserver.talk.application.service.TalkModerationService;
import java.time.LocalDateTime;
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

/// 신고·차단 API 의 문 앞: 토큰이 없으면 401, 이룸이 권한이면 403, 보호자만 통과한다.
@WebMvcTest(controllers = TalkModerationController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class TalkModerationSecurityTest {

  private static final SimpleGrantedAuthority MEMBER = new SimpleGrantedAuthority("ROLE_MEMBER");
  private static final SimpleGrantedAuthority GUARDIAN = new SimpleGrantedAuthority("ROLE_GUARDIAN");
  private static final SimpleGrantedAuthority ELUMI = new SimpleGrantedAuthority("ROLE_ELUMI");

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private TalkModerationService talkModerationService;

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
  @DisplayName("이룸이 권한으로는 신고·차단 어느 것도 부를 수 없다")
  void allEndpoints_asElumi_are403() throws Exception {
    var elumi = user("e1").authorities(MEMBER, ELUMI);

    mockMvc.perform(post("/api/talk/reports").with(elumi).contentType("application/json")
      .content("{\"targetType\":\"POST\",\"targetId\":\"p1\",\"reason\":\"OTHER\"}")).andExpect(status().isForbidden());
    mockMvc.perform(put("/api/talk/blocks").with(elumi).contentType("application/json")
      .content("{\"postId\":\"p1\"}")).andExpect(status().isForbidden());
    mockMvc.perform(get("/api/talk/blocks").with(elumi)).andExpect(status().isForbidden());
    mockMvc.perform(delete("/api/talk/blocks/b1").with(elumi)).andExpect(status().isForbidden());

    verifyNoInteractions(talkModerationService);
  }

  @Test
  @DisplayName("토큰 없이 차단 목록을 부르면 401 이다")
  void blocks_withoutToken_is401() throws Exception {
    mockMvc.perform(get("/api/talk/blocks")).andExpect(status().isUnauthorized());

    verifyNoInteractions(talkModerationService);
  }

  @Test
  @DisplayName("보호자는 신고·차단·해제가 204, 목록이 200 으로 서비스에 닿는다")
  void guardian_reachesService() throws Exception {
    var guardian = user("g1").authorities(MEMBER, GUARDIAN);
    when(talkModerationService.blocks(any())).thenReturn(
      List.of(new TalkBlockResponse("b1", "이웃", LocalDateTime.of(2026, 10, 20, 9, 0))));

    mockMvc.perform(post("/api/talk/reports").with(guardian).contentType("application/json")
      .content("{\"targetType\":\"POST\",\"targetId\":\"p1\",\"reason\":\"OTHER\"}")).andExpect(status().isNoContent());
    mockMvc.perform(put("/api/talk/blocks").with(guardian).contentType("application/json")
      .content("{\"postId\":\"p1\"}")).andExpect(status().isNoContent());
    mockMvc.perform(get("/api/talk/blocks").with(guardian))
      .andExpect(status().isOk()).andExpect(jsonPath("$[0].blockId").value("b1"))
      .andExpect(jsonPath("$[0].nickname").value("이웃"));
    mockMvc.perform(delete("/api/talk/blocks/b1").with(guardian)).andExpect(status().isNoContent());

    verify(talkModerationService).report(any(), any());
    verify(talkModerationService).block(any(), any());
    verify(talkModerationService).unblock(any(), eq("b1"));
  }

  @Test
  @DisplayName("중복 신고는 409, 자기 차단은 400 으로 답한다")
  void errors_mapToStatus() throws Exception {
    var guardian = user("g1").authorities(MEMBER, GUARDIAN);
    doThrow(new CustomException(ErrorCode.TALK_REPORT_DUPLICATED)).when(talkModerationService).report(any(), any());
    doThrow(new CustomException(ErrorCode.TALK_CANNOT_BLOCK_SELF)).when(talkModerationService).block(any(), any());

    mockMvc.perform(post("/api/talk/reports").with(guardian).contentType("application/json")
      .content("{\"targetType\":\"POST\",\"targetId\":\"p1\",\"reason\":\"OTHER\"}")).andExpect(status().isConflict());
    mockMvc.perform(put("/api/talk/blocks").with(guardian).contentType("application/json")
      .content("{\"postId\":\"p1\"}")).andExpect(status().isBadRequest());
  }
}
