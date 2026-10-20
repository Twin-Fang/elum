package com.chuseok22.elumserver.talk.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.chuseok22.elumserver.common.infrastructure.security.AidlpCryptoService;
import com.chuseok22.elumserver.common.infrastructure.security.NonceStore;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.talk.application.dto.response.TalkFeedPageResponse;
import com.chuseok22.elumserver.talk.application.service.TalkFeedQueryService;
import com.chuseok22.elumserver.talk.application.service.TalkPostService;
import java.util.List;
import java.util.Map;
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

/// 이야기 API 의 문 앞: 토큰이 없으면 401, 이룸이 권한이면 403, 보호자만 통과한다.
@WebMvcTest(controllers = TalkController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class})
class TalkSecurityTest {

  private static final SimpleGrantedAuthority MEMBER = new SimpleGrantedAuthority("ROLE_MEMBER");
  private static final SimpleGrantedAuthority GUARDIAN = new SimpleGrantedAuthority("ROLE_GUARDIAN");
  private static final SimpleGrantedAuthority ELUMI = new SimpleGrantedAuthority("ROLE_ELUMI");

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private TalkFeedQueryService talkFeedQueryService;
  @MockitoBean
  private TalkPostService talkPostService;

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
  @DisplayName("토큰 없이 피드를 부르면 401 이다")
  void feed_withoutToken_is401() throws Exception {
    mockMvc.perform(get("/api/talk/posts")).andExpect(status().isUnauthorized());

    verify(talkFeedQueryService, never()).feed(any(), any(), any(), any(), any());
  }

  @Test
  @DisplayName("이룸이 휴대폰 권한으로는 피드를 부를 수 없다")
  void feed_asElumi_is403() throws Exception {
    mockMvc.perform(get("/api/talk/posts").with(user("e1").authorities(MEMBER, ELUMI)))
      .andExpect(status().isForbidden());

    verify(talkFeedQueryService, never()).feed(any(), any(), any(), any(), any());
  }

  @Test
  @DisplayName("보호자는 피드를 받고, 언어는 요청 언어(기본 KO)를 넘긴다")
  void feed_asGuardian_works() throws Exception {
    when(talkFeedQueryService.feed(any(), any(), any(), any(), any()))
      .thenReturn(new TalkFeedPageResponse(List.of(), null));

    mockMvc.perform(get("/api/talk/posts?category=DAILY_FLOW&size=5")
        .with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.items").isArray());

    verify(talkFeedQueryService).feed(any(), eq("DAILY_FLOW"), eq(null), eq(5), eq(AppLocale.KO));
  }

  @Test
  @DisplayName("이룸이 권한으로는 인기·상세·그림·내 글 매핑·미리보기·올리기도 403 이다")
  void otherEndpoints_asElumi_are403() throws Exception {
    var elumi = user("e1").authorities(MEMBER, ELUMI);

    mockMvc.perform(get("/api/talk/posts/popular").with(elumi)).andExpect(status().isForbidden());
    mockMvc.perform(get("/api/talk/posts/mine/by-source-routine").with(elumi)).andExpect(status().isForbidden());
    mockMvc.perform(get("/api/talk/posts/p1").with(elumi)).andExpect(status().isForbidden());
    mockMvc.perform(get("/api/talk/posts/p1/steps/0/image").with(elumi)).andExpect(status().isForbidden());
    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/talk/posts")
      .with(elumi).contentType("application/json").content("{}")).andExpect(status().isForbidden());
    mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/talk/posts/preview")
      .with(elumi).contentType("application/json").content("{}")).andExpect(status().isForbidden());
  }

  @Test
  @DisplayName("내 글 매핑은 원본 일과 id > 글 id 맵으로 나온다 (mine 이 {id} 로 잡히지 않는다)")
  void mineBySourceRoutine_returnsMap() throws Exception {
    when(talkFeedQueryService.mySharedPosts(any())).thenReturn(Map.of("routine-1", "post-1"));

    mockMvc.perform(get("/api/talk/posts/mine/by-source-routine").with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.routine-1").value("post-1"));
  }

  @Test
  @DisplayName("그림은 비공개 캐시 하루로 내려준다")
  void stepImage_isPrivateCachedForOneDay() throws Exception {
    when(talkFeedQueryService.stepImage("p1", 0)).thenReturn(new ImageContent(new byte[] {1, 2, 3}, "image/jpeg"));

    mockMvc.perform(get("/api/talk/posts/p1/steps/0/image").with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isOk())
      .andExpect(header().string("Cache-Control", "private, max-age=86400"))
      .andExpect(header().string("Content-Type", "image/jpeg"));
  }

  @Test
  @DisplayName("내려간 글 상세는 404 로 답한다")
  void detail_notFound_is404() throws Exception {
    when(talkFeedQueryService.detail(any(), eq("gone"))).thenThrow(new CustomException(ErrorCode.TALK_POST_NOT_FOUND));

    mockMvc.perform(get("/api/talk/posts/gone").with(user("g1").authorities(MEMBER, GUARDIAN)))
      .andExpect(status().isNotFound());
  }
}
