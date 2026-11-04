package com.chuseok22.elumserver.license.infrastructure.store.google;

import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.license.application.service.store.StoreTemporarilyUnavailableException;
import com.fasterxml.jackson.databind.JsonNode;
import com.google.auth.oauth2.AccessToken;
import com.google.auth.oauth2.GoogleCredentials;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * Google Play Developer API 호출: JDK HttpClient (연결 3초·응답 8초) + 서비스 계정 토큰 (google-auth-library 가 캐시·갱신)
 * 응답 코드: 200 > 조회 값, 400·404·410 > 없는 토큰, 그 외 > 확인 중
 */
@Slf4j
@Component
public class HttpGooglePlayDeveloperClient implements GooglePlayDeveloperClient {

  private static final String API_BASE_URL = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/";
  private static final String ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
  private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(3);
  private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(8);
  private static final int HTTP_OK = 200;
  private static final int HTTP_NO_CONTENT = 204;
  // 토큰이 틀렸거나 오래돼 지워진 구매
  private static final Set<Integer> NOT_FOUND_STATUSES = Set.of(400, 404, 410);

  private final HttpClient httpClient = HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build();
  // 서비스 계정 JSON 이 바뀔 때만 새로 읽는다 (토큰 캐시를 살리려고)
  private volatile CachedCredentials cachedCredentials;

  @Override
  public Optional<JsonNode> fetchSubscription(String packageName, String purchaseToken, String serviceAccountJson) {
    URI uri = URI.create(API_BASE_URL + encode(packageName) + "/purchases/subscriptionsv2/tokens/" + encode(purchaseToken));
    HttpRequest request = authorized(HttpRequest.newBuilder(uri), serviceAccountJson).GET().build();
    HttpResponse<String> response = send(request);
    if (NOT_FOUND_STATUSES.contains(response.statusCode())) {
      return Optional.empty();
    }
    if (response.statusCode() != HTTP_OK) {
      throw unavailable("subscriptionsv2.get", response.statusCode());
    }
    try {
      return Optional.of(DefaultJsonMapper.SHARED.readTree(response.body()));
    } catch (IOException e) {
      throw new StoreTemporarilyUnavailableException("google response unreadable", e);
    }
  }

  @Override
  public void acknowledge(String packageName, String productId, String purchaseToken, String serviceAccountJson) {
    URI uri = URI.create(API_BASE_URL + encode(packageName) + "/purchases/subscriptions/" + encode(productId)
      + "/tokens/" + encode(purchaseToken) + ":acknowledge");
    HttpRequest request = authorized(HttpRequest.newBuilder(uri), serviceAccountJson)
      .header("Content-Type", "application/json")
      .POST(HttpRequest.BodyPublishers.ofString("{}"))
      .build();
    HttpResponse<String> response = send(request);
    if (response.statusCode() != HTTP_OK && response.statusCode() != HTTP_NO_CONTENT) {
      throw unavailable("acknowledge", response.statusCode());
    }
  }

  private HttpRequest.Builder authorized(HttpRequest.Builder builder, String serviceAccountJson) {
    return builder.timeout(REQUEST_TIMEOUT).header("Authorization", "Bearer " + accessTokenOf(serviceAccountJson));
  }

  private HttpResponse<String> send(HttpRequest request) {
    try {
      return httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
    } catch (IOException e) {
      throw new StoreTemporarilyUnavailableException("google api io failure", e);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new StoreTemporarilyUnavailableException("google api interrupted", e);
    }
  }

  private String accessTokenOf(String serviceAccountJson) {
    try {
      GoogleCredentials credentials = credentialsOf(serviceAccountJson);
      credentials.refreshIfExpired();
      AccessToken token = credentials.getAccessToken();
      if (token == null) {
        throw new StoreTemporarilyUnavailableException("google access token empty");
      }
      return token.getTokenValue();
    } catch (IOException e) {
      throw new StoreTemporarilyUnavailableException("google access token failure", e);
    } catch (RuntimeException e) {
      if (e instanceof StoreTemporarilyUnavailableException) {
        throw e;
      }
      // 서비스 계정 JSON 형식 오류 (설정 문제, 구매를 버리지 않도록 확인 중으로)
      log.error("[subscription verify] google credentials invalid : {}", e.getClass().getSimpleName());
      throw new StoreTemporarilyUnavailableException("google credentials invalid", e);
    }
  }

  private GoogleCredentials credentialsOf(String serviceAccountJson) throws IOException {
    CachedCredentials cached = cachedCredentials;
    int jsonHash = serviceAccountJson.hashCode();
    if (cached != null && cached.jsonHash() == jsonHash) {
      return cached.credentials();
    }
    GoogleCredentials credentials = GoogleCredentials
      .fromStream(new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8)))
      .createScoped(List.of(ANDROID_PUBLISHER_SCOPE));
    cachedCredentials = new CachedCredentials(jsonHash, credentials);
    return credentials;
  }

  private static StoreTemporarilyUnavailableException unavailable(String operation, int statusCode) {
    log.warn("[subscription verify] google api failed : operation={}, status={}", operation, statusCode);
    return new StoreTemporarilyUnavailableException("google " + operation + " status " + statusCode);
  }

  private static String encode(String pathSegment) {
    return URLEncoder.encode(pathSegment, StandardCharsets.UTF_8).replace("+", "%20");
  }

  private record CachedCredentials(int jsonHash, GoogleCredentials credentials) {

  }
}
