package com.chuseok22.elumserver.talk.application.dto.response;

import com.chuseok22.elumserver.talk.application.dto.request.TalkShareVisitor;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * 공유 페이지 앱 열기 주소 3개: 앱 주소(elum://talk?post=), Android 버튼 intent(없으면 Play), 자동 열기(안 부르면 null)
 * 자동 열기: Android 전부 intent(앱 없으면 같은 페이지 ?app=0), iOS 는 내장 브라우저만 (Safari 는 앱 없으면 오류 창)
 */
public record TalkShareAppLinks(String appUrl, String androidIntentUrl, String autoOpenUrl) {

  // 앱 주소 모양: 앱 TalkPostLink 와 같아야 함
  private static final String APP_SCHEME = "elum";
  private static final String APP_POST_PATH = "talk?post=";
  // 자동 열기에서 돌아온 표시: ?app=0 (앱 없음 > 다시 부르지 않음)
  public static final String AUTO_OPEN_DONE_PARAMETER = "app";
  public static final String AUTO_OPEN_DONE_VALUE = "0";

  /**
   * 글 1건의 앱 열기 주소: 기기·이미 시도했는지 > 자동 열기 주소 결정
   */
  public static TalkShareAppLinks of(
    String postId,
    String pageUrl,
    String packageName,
    String playStoreUrl,
    TalkShareVisitor visitor,
    boolean hasTriedAutoOpen
  ) {
    String appUrl = APP_SCHEME + "://" + APP_POST_PATH + postId;
    String androidIntentUrl = intentUrl(postId, packageName, playStoreUrl);
    String autoOpenUrl = null;
    if (!hasTriedAutoOpen && visitor.isAndroid()) {
      String returnUrl = pageUrl + "?" + AUTO_OPEN_DONE_PARAMETER + "=" + AUTO_OPEN_DONE_VALUE;
      autoOpenUrl = intentUrl(postId, packageName, returnUrl);
    } else if (!hasTriedAutoOpen && visitor.isIos() && visitor.isInAppBrowser()) {
      autoOpenUrl = appUrl;
    }
    return new TalkShareAppLinks(appUrl, androidIntentUrl, autoOpenUrl);
  }

  // intent://talk?post={글id}#Intent;scheme=elum;package={패키지};S.browser_fallback_url={앱 없을 때 갈 주소};end
  private static String intentUrl(String postId, String packageName, String fallbackUrl) {
    return "intent://" + APP_POST_PATH + postId
      + "#Intent;scheme=" + APP_SCHEME
      + ";package=" + packageName
      + ";S.browser_fallback_url=" + URLEncoder.encode(fallbackUrl, StandardCharsets.UTF_8)
      + ";end";
  }
}
