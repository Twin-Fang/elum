package com.chuseok22.elumserver.talk.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.application.controller.AppLinkAssociationController;
import com.chuseok22.elumserver.common.infrastructure.config.SecurityConfig;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkShareProperties;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.talk.application.dto.response.TalkSharePage;
import com.chuseok22.elumserver.talk.application.service.TalkSharePageService;
import java.nio.charset.StandardCharsets;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.mapping.JpaMetamodelMappingContext;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/// 공유 링크의 문 앞: 로그인 없이 열리고(카톡 스크래퍼·앱 없는 사람), 글 값은 이스케이프되고, 볼 수 없는 글은 404 안내.
@WebMvcTest(controllers = {TalkSharePageController.class, AppLinkAssociationController.class})
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class, TalkSharePageControllerTest.PropertiesConfig.class})
class TalkSharePageControllerTest {

  private static final String POST_ID = "0b6f6b1e-3c1a-4f7e-9d7a-2a4c5e6f7a8b";

  @TestConfiguration
  @EnableConfigurationProperties(TalkShareProperties.class)
  static class PropertiesConfig {
  }

  @Autowired
  private MockMvc mockMvc;

  @MockitoBean
  private TalkSharePageService talkSharePageService;

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
  @DisplayName("로그인 없이 공유 페이지가 열리고 OG·앱 주소가 실리며 글 값은 이스케이프된다")
  void page_visiblePost_rendersPreviewWithoutLogin() throws Exception {
    when(talkSharePageService.page(POST_ID)).thenReturn(Optional.of(
      new TalkSharePage(POST_ID, "하루 순서", "<script>alert(1)</script>아침", "같이 해요", 3)));

    String html = mockMvc.perform(get("/s/" + POST_ID).header(HttpHeaders.USER_AGENT, "KAKAOTALK Android"))
      .andExpect(status().isOk())
      .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);

    assertThat(html).contains("<meta property=\"og:image\" content=\"https://api.elum.chuseok22.com/s/" + POST_ID + "/thumbnail\"");
    assertThat(html).contains("href=\"elum://talk?post=" + POST_ID + "\"");
    assertThat(html).contains("&lt;script&gt;alert(1)&lt;/script&gt;아침").doesNotContain("<script>alert(1)");
    // 안드로이드 기기는 Play 만
    assertThat(html).contains("play.google.com").doesNotContain("apps.apple.com");
  }

  @Test
  @DisplayName("볼 수 없는 글은 404 + 에러 코드 + 기본 미리보기 그림 (앱 주소 없음)")
  void page_missingPost_rendersGoneWith404() throws Exception {
    when(talkSharePageService.page(POST_ID)).thenReturn(Optional.empty());

    String html = mockMvc.perform(get("/s/" + POST_ID))
      .andExpect(status().isNotFound())
      .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);

    assertThat(html).contains("E-TALK-SHARE-GONE").contains("twin-fang.github.io/elum/assets/og.png")
      .doesNotContain("elum://talk");
  }

  @Test
  @DisplayName("썸네일이 없으면 기본 그림으로 302")
  void thumbnail_missing_redirectsToDefaultImage() throws Exception {
    when(talkSharePageService.thumbnail(POST_ID)).thenReturn(Optional.empty());

    mockMvc.perform(get("/s/" + POST_ID + "/thumbnail"))
      .andExpect(status().isFound())
      .andExpect(header().string(HttpHeaders.LOCATION, "https://twin-fang.github.io/elum/assets/og.png"));
  }

  @Test
  @DisplayName("앱 연결 검증 파일은 로그인 없이 JSON 으로 열린다 (iOS 앱 id · /s/* 경로)")
  void wellKnown_servedWithoutLogin() throws Exception {
    String aasa = mockMvc.perform(get("/.well-known/apple-app-site-association"))
      .andExpect(status().isOk())
      .andExpect(header().string(HttpHeaders.CONTENT_TYPE, "application/json"))
      .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
    assertThat(aasa).contains("CUK22HY6YC.kr.twinfang.elum").contains("/s/*");

    mockMvc.perform(get("/.well-known/assetlinks.json"))
      .andExpect(status().isOk());
  }
}
