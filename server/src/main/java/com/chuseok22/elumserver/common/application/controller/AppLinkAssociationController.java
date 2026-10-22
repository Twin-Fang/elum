package com.chuseok22.elumserver.common.application.controller;

import com.chuseok22.elumserver.common.infrastructure.properties.TalkShareProperties;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 앱 연결 검증 파일 2개 (인증 없음): iOS Universal Links, Android App Links
 * OS 가 이 도메인의 /s/* 링크를 브라우저 대신 앱으로 열어도 되는지 확인할 때 읽음
 */
@RestController
@RequiredArgsConstructor
public class AppLinkAssociationController {

  // 앱이 받는 경로: 이야기 글 공유 링크 (/s/{글id}, 썸네일 /s/{글id}/thumbnail 도 앱으로 감 — 앱이 무시)
  private static final String SHARE_PATH_PATTERN = "/s/*";
  private static final String ANDROID_HANDLE_ALL_URLS = "delegate_permission/common.handle_all_urls";

  private final TalkShareProperties talkShareProperties;

  /**
   * iOS: appIDs + components (iOS 13+), appID + paths (iOS 12 이하 형식 함께)
   */
  @GetMapping("/.well-known/apple-app-site-association")
  public ResponseEntity<Map<String, Object>> appleAppSiteAssociation() {
    String appId = talkShareProperties.iosAppId();
    Map<String, Object> detail = Map.of(
      "appIDs", List.of(appId),
      "components", List.of(Map.of("/", SHARE_PATH_PATTERN)),
      "appID", appId,
      "paths", List.of(SHARE_PATH_PATTERN)
    );
    return ResponseEntity.ok()
      .contentType(MediaType.APPLICATION_JSON)
      .body(Map.of("applinks", Map.of("apps", List.of(), "details", List.of(detail))));
  }

  /**
   * Android: 패키지 + 앱 서명 인증서 SHA-256 (설정이 비면 빈 배열 > 검증 실패 > 링크는 웹 페이지로 열림)
   */
  @GetMapping("/.well-known/assetlinks.json")
  public ResponseEntity<List<Map<String, Object>>> assetLinks() {
    List<String> fingerprints = talkShareProperties.androidCertSha256();
    if (fingerprints.isEmpty()) {
      return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(List.of());
    }
    Map<String, Object> statement = Map.of(
      "relation", List.of(ANDROID_HANDLE_ALL_URLS),
      "target", Map.of(
        "namespace", "android_app",
        "package_name", talkShareProperties.androidPackageName(),
        "sha256_cert_fingerprints", fingerprints
      )
    );
    return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(List.of(statement));
  }
}
