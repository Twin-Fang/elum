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
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentResponse;
import com.chuseok22.elumserver.talk.application.service.TalkReactionService;
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

/// 이야기 반응 API 의 문 앞: 토큰이 없으면 401, 이룸이 권한이면 403, 보호자만 통과한다.
@WebMvcTest(controllers = TalkReactionController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class TalkReactionSecurityTest {

  private static final SimpleGrantedAuthority MEMBER = new SimpleGrantedAuthority("ROLE_MEMBER");
  private static final SimpleGrantedAuthority GUARDIAN = new SimpleGrantedAuthority("ROLE_GUARDIAN");
  private static final SimpleGrantedAuthority ELUMI = new SimpleGrantedAuthority("ROLE_ELUMI");

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private TalkReactionService talkReactionService;

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
  @DisplayName("이룸이 권한으로는 도움이 됐어요·댓글 어느 것도 부를 수 없다")
  void allEndpoints_asElumi_are403() throws Exception {
    var elumi = user("e1").authorities(MEMBER, ELUMI);

    mockMvc.perform(put("/api/talk/posts/p1/helpful").with(elumi)).andExpect(status().isForbidden());
    mockMvc.perform(delete("/api/talk/posts/p1/helpful").with(elumi)).andExpect(status().isForbidden());
    mockMvc.perform(get("/api/talk/posts/p1/comments").with(elumi)).andExpect(status().isForbidden());
    mockMvc.perform(post("/api/talk/posts/p1/comments").with(elumi).contentType("application/json")
      .content("{\"body\":\"안녕\"}")).andExpect(status().isForbidden());
    mockMvc.perform(delete("/api/talk/comments/c1").with(elumi)).andExpect(status().isForbidden());

    verifyNoInteractions(talkReactionService);
  }

  @Test
  @DisplayName("토큰 없이 댓글 목록을 부르면 401 이다")
  void comments_withoutToken_is401() throws Exception {
    mockMvc.perform(get("/api/talk/posts/p1/comments")).andExpect(status().isUnauthorized());

    verifyNoInteractions(talkReactionService);
  }

  @Test
  @DisplayName("보호자는 도움이 됐어요 누르기·취소·댓글 지우기가 204, 댓글 쓰기·목록이 200 으로 서비스에 닿는다")
  void guardian_reachesService() throws Exception {
    var guardian = user("g1").authorities(MEMBER, GUARDIAN);
    when(talkReactionService.comments(any(), eq("p1"), eq(null), eq(10)))
      .thenReturn(new TalkCommentPageResponse(List.of(), null));
    when(talkReactionService.addComment(any(), eq("p1"), any()))
      .thenReturn(new TalkCommentResponse("c1", "이웃", true, "안녕", LocalDateTime.of(2026, 10, 20, 9, 0), false, false));

    mockMvc.perform(put("/api/talk/posts/p1/helpful").with(guardian)).andExpect(status().isNoContent());
    mockMvc.perform(delete("/api/talk/posts/p1/helpful").with(guardian)).andExpect(status().isNoContent());
    mockMvc.perform(get("/api/talk/posts/p1/comments?size=10").with(guardian))
      .andExpect(status().isOk()).andExpect(jsonPath("$.items").isArray());
    mockMvc.perform(post("/api/talk/posts/p1/comments").with(guardian).contentType("application/json")
        .content("{\"body\":\"안녕\"}"))
      .andExpect(status().isOk()).andExpect(jsonPath("$.id").value("c1")).andExpect(jsonPath("$.isMine").value(true));
    mockMvc.perform(delete("/api/talk/comments/c1").with(guardian)).andExpect(status().isNoContent());

    verify(talkReactionService).markHelpful(any(), eq("p1"));
    verify(talkReactionService).unmarkHelpful(any(), eq("p1"));
    verify(talkReactionService).deleteComment(any(), eq("c1"));
  }

  @Test
  @DisplayName("남의 댓글 지우기는 403, 없는 댓글은 404 로 답한다")
  void deleteComment_errors_mapToStatus() throws Exception {
    var guardian = user("g1").authorities(MEMBER, GUARDIAN);
    doThrow(new CustomException(ErrorCode.TALK_NOT_AUTHOR)).when(talkReactionService).deleteComment(any(), eq("other"));
    doThrow(new CustomException(ErrorCode.TALK_COMMENT_NOT_FOUND)).when(talkReactionService).deleteComment(any(), eq("gone"));

    mockMvc.perform(delete("/api/talk/comments/other").with(guardian)).andExpect(status().isForbidden());
    mockMvc.perform(delete("/api/talk/comments/gone").with(guardian)).andExpect(status().isNotFound());
  }
}
