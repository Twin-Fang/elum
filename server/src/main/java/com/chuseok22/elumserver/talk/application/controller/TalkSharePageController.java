package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.common.infrastructure.properties.TalkShareProperties;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.request.TalkShareVisitor;
import com.chuseok22.elumserver.talk.application.dto.response.TalkShareAppLinks;
import com.chuseok22.elumserver.talk.application.dto.response.TalkSharePage;
import com.chuseok22.elumserver.talk.application.service.TalkSharePageService;
import jakarta.servlet.http.HttpServletResponse;
import java.net.URI;
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
import org.springframework.web.bind.annotation.RequestParam;

/**
 * 이야기 글 공유 링크 (인증 없음, /api·/admin 밖): 미리보기 페이지, 썸네일
 * 링크 {공유 기준 주소}/s/{글id} > 메신저 미리보기(OG) · 앱 있으면 그 글로 열기 · 없으면 앱 소개와 스토어
 */
@Controller
@RequiredArgsConstructor
public class TalkSharePageController {

  // 썸네일 캐시 (1시간). 글을 고쳐도 메신저 미리보기는 그쪽 캐시를 따름
  private static final String THUMBNAIL_CACHE_CONTROL = "public, max-age=3600";
  private static final String VIEW_NAME = "share/talk-post";

  private final TalkSharePageService talkSharePageService;
  private final TalkShareProperties talkShareProperties;

  /**
   * 공유 페이지: 공개 글이면 미리보기 + 앱 열기(기기에 따라 자동 1회), 아니면 찾을 수 없음 안내 (404) — 둘 다 앱 소개·스토어 버튼
   */
  @GetMapping("/s/{postId}")
  public String page(
    @PathVariable String postId,
    @RequestParam(value = TalkShareAppLinks.AUTO_OPEN_DONE_PARAMETER, required = false) String autoOpenDone,
    @RequestHeader(value = HttpHeaders.USER_AGENT, required = false) String userAgent,
    Model model,
    HttpServletResponse response
  ) {
    Optional<TalkSharePage> page = talkSharePageService.page(postId);
    if (page.isEmpty()) {
      response.setStatus(HttpStatus.NOT_FOUND.value());
    }
    String baseUrl = talkShareProperties.publicBaseUrl();
    String pageUrl = page.map(found -> baseUrl + "/s/" + found.postId()).orElse(baseUrl);
    TalkShareVisitor visitor = TalkShareVisitor.from(userAgent);
    boolean hasTriedAutoOpen = TalkShareAppLinks.AUTO_OPEN_DONE_VALUE.equals(autoOpenDone);

    model.addAttribute("post", page.orElse(null));
    model.addAttribute("pageUrl", pageUrl);
    model.addAttribute("imageUrl", page.map(found -> baseUrl + "/s/" + found.postId() + "/thumbnail")
      .orElse(talkShareProperties.defaultImageUrl()));
    TalkShareAppLinks links = page.map(found -> TalkShareAppLinks.of(found.postId(), pageUrl,
      talkShareProperties.androidPackageName(), talkShareProperties.playStoreUrl(), visitor, hasTriedAutoOpen))
      .orElse(null);
    model.addAttribute("links", links);
    model.addAttribute("platform", visitor.platform());
    model.addAttribute("appleAppBanner", appleAppBannerOf(links == null ? null : links.appUrl()));
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

  // Safari 앱 배너: app-id={앱 번호}, app-argument={앱 주소} (배너의 열기 > 그 글, 앱 번호 없으면 배너 없음)
  private String appleAppBannerOf(String appUrl) {
    String appId = talkShareProperties.appStoreAppId();
    if (appId == null) {
      return null;
    }
    return appUrl == null ? "app-id=" + appId : "app-id=" + appId + ", app-argument=" + appUrl;
  }
}
