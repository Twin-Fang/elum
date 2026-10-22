package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.common.infrastructure.properties.TalkShareProperties;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkSharePage;
import com.chuseok22.elumserver.talk.application.service.TalkSharePageService;
import jakarta.servlet.http.HttpServletResponse;
import java.net.URI;
import java.util.Locale;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;

/**
 * 이야기 글 공유 링크 (인증 없음, /api·/admin 밖): 미리보기 페이지, 썸네일
 * 링크 {공유 기준 주소}/s/{글id} > 메신저 미리보기(OG) · 앱 있으면 앱 주소로 열기 · 없으면 스토어 안내
 */
@Controller
@RequiredArgsConstructor
public class TalkSharePageController {

  // 앱 주소: 앱 TalkPostLink 와 같은 모양 (elum://talk?post={글id})
  private static final String APP_URL_PREFIX = "elum://talk?post=";
  // 썸네일 캐시 (1시간). 글을 고쳐도 메신저 미리보기는 그쪽 캐시를 따름
  private static final String THUMBNAIL_CACHE_CONTROL = "public, max-age=3600";
  private static final String VIEW_NAME = "share/talk-post";

  private final TalkSharePageService talkSharePageService;
  private final TalkShareProperties talkShareProperties;

  /**
   * 공유 페이지: 공개 글이면 미리보기 + 앱 열기, 아니면 찾을 수 없음 안내 (404) — 둘 다 스토어 버튼
   */
  @GetMapping("/s/{postId}")
  public String page(
    @PathVariable String postId,
    @RequestHeader(value = HttpHeaders.USER_AGENT, required = false) String userAgent,
    Model model,
    HttpServletResponse response
  ) {
    Optional<TalkSharePage> page = talkSharePageService.page(postId);
    if (page.isEmpty()) {
      response.setStatus(HttpStatus.NOT_FOUND.value());
    }
    String baseUrl = talkShareProperties.publicBaseUrl();
    model.addAttribute("post", page.orElse(null));
    model.addAttribute("pageUrl", page.map(found -> baseUrl + "/s/" + found.postId()).orElse(baseUrl));
    model.addAttribute("imageUrl", page.map(found -> baseUrl + "/s/" + found.postId() + "/thumbnail")
      .orElse(talkShareProperties.defaultImageUrl()));
    model.addAttribute("appUrl", page.map(found -> APP_URL_PREFIX + found.postId()).orElse(null));
    model.addAttribute("platform", platformOf(userAgent));
    model.addAttribute("playStoreUrl", talkShareProperties.playStoreUrl());
    model.addAttribute("appStoreUrl", talkShareProperties.appStoreUrl());
    return VIEW_NAME;
  }

  /**
   * 썸네일: 그림이 있는 첫 카드, 없거나 볼 수 없으면 기본 미리보기 그림으로 302
   */
  @GetMapping("/s/{postId}/thumbnail")
  public ResponseEntity<byte[]> thumbnail(@PathVariable String postId) {
    Optional<ImageContent> content = talkSharePageService.thumbnail(postId);
    if (content.isEmpty()) {
      return ResponseEntity.status(HttpStatus.FOUND)
        .location(URI.create(talkShareProperties.defaultImageUrl()))
        .build();
    }
    return ResponseEntity.ok()
      .header(HttpHeaders.CACHE_CONTROL, THUMBNAIL_CACHE_CONTROL)
      .contentType(MediaType.parseMediaType(content.get().contentType()))
      .body(content.get().bytes());
  }

  // 기기 3갈래: android, ios, other (스토어 버튼 고르기용, 카톡 인앱 브라우저 UA 포함)
  private static String platformOf(String userAgent) {
    String lowered = userAgent == null ? "" : userAgent.toLowerCase(Locale.ROOT);
    if (lowered.contains("android")) {
      return "android";
    }
    if (lowered.contains("iphone") || lowered.contains("ipad") || lowered.contains("ipod")) {
      return "ios";
    }
    return "other";
  }
}
