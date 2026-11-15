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
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
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
  // 해지 유형: 사용자 요청 해지 (다음 갱신만 멈춤, 사용자가 스토어에서 되살릴 수 있음)
  private static final String CANCEL_REQUEST_BODY =
    "{\"cancellationContext\":{\"cancellationType\":\"USER_REQUESTED_STOP_RENEWALS\"}}";
  // voidedpurchases.list type=1: 일회성 상품 + 구독 (기본 0 은 일회성 상품만)
  private static final int VOIDED_TYPE_INCLUDING_SUBSCRIPTIONS = 1;
  // 한 번에 받는 취소 구매 수 (API 최대 1,000)
  private static final int VOIDED_PAGE_SIZE = 1000;
  // 끝없는 페이지 방지: 1,000건 x 50쪽
  private static final int VOIDED_MAX_PAGES = 50;
  // orders.batchGet 한 번에 물을 주문 수 (API 최대 1,000, 주소 길이 여유로 100)
  private static final int ORDER_BATCH_SIZE = 100;
  // Order.state: 전액 환불 (부분 환불 PARTIALLY_REFUNDED 는 회수하지 않음)
  private static final String ORDER_STATE_REFUNDED = "REFUNDED";

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
  public Optional<JsonNode> fetchProductPurchase(
    String packageName, String productId, String purchaseToken, String serviceAccountJson
  ) {
    URI uri = URI.create(API_BASE_URL + encode(packageName) + "/purchases/products/" + encode(productId)
      + "/tokens/" + encode(purchaseToken));
    HttpResponse<String> response = send(authorized(HttpRequest.newBuilder(uri), serviceAccountJson).GET().build());
    if (NOT_FOUND_STATUSES.contains(response.statusCode())) {
      return Optional.empty();
    }
    if (response.statusCode() != HTTP_OK) {
      throw unavailable("products.get", response.statusCode());
    }
    try {
      return Optional.of(DefaultJsonMapper.SHARED.readTree(response.body()));
    } catch (IOException e) {
      throw new StoreTemporarilyUnavailableException("google response unreadable", e);
    }
  }

  @Override
  public void consumeProduct(String packageName, String productId, String purchaseToken, String serviceAccountJson) {
    URI uri = URI.create(API_BASE_URL + encode(packageName) + "/purchases/products/" + encode(productId)
      + "/tokens/" + encode(purchaseToken) + ":consume");
    HttpRequest request = authorized(HttpRequest.newBuilder(uri), serviceAccountJson)
      .header("Content-Type", "application/json")
      .POST(HttpRequest.BodyPublishers.ofString("{}"))
      .build();
    HttpResponse<String> response = send(request);
    if (response.statusCode() != HTTP_OK && response.statusCode() != HTTP_NO_CONTENT) {
      throw unavailable("products.consume", response.statusCode());
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

  @Override
  public void cancelSubscription(String packageName, String purchaseToken, String serviceAccountJson) {
    URI uri = URI.create(API_BASE_URL + encode(packageName) + "/purchases/subscriptionsv2/tokens/" + encode(purchaseToken) + ":cancel");
    HttpRequest request = authorized(HttpRequest.newBuilder(uri), serviceAccountJson)
      .header("Content-Type", "application/json")
      .POST(HttpRequest.BodyPublishers.ofString(CANCEL_REQUEST_BODY))
      .build();
    HttpResponse<String> response = send(request);
    if (response.statusCode() != HTTP_OK && response.statusCode() != HTTP_NO_CONTENT) {
      throw unavailable("subscriptionsv2.cancel", response.statusCode());
    }
  }

  @Override
  public List<VoidedPurchase> listVoidedPurchases(String packageName, long startTimeMillis, String serviceAccountJson) {
    List<VoidedPurchase> voidedPurchases = new ArrayList<>();
    String pageToken = null;
    // 끝 페이지까지 (nextPageToken 이 없을 때까지)
    for (int page = 0; page < VOIDED_MAX_PAGES; page++) {
      String uri = API_BASE_URL + encode(packageName) + "/purchases/voidedpurchases?startTime=" + startTimeMillis
        + "&type=" + VOIDED_TYPE_INCLUDING_SUBSCRIPTIONS + "&maxResults=" + VOIDED_PAGE_SIZE
        + (pageToken == null ? "" : "&token=" + encode(pageToken));
      JsonNode body = getJson(URI.create(uri), "voidedpurchases.list", serviceAccountJson);
      for (JsonNode voided : body.path("voidedPurchases")) {
        voidedPurchases.add(new VoidedPurchase(textOrNull(voided.path("purchaseToken")), textOrNull(voided.path("orderId"))));
      }
      pageToken = textOrNull(body.path("tokenPagination").path("nextPageToken"));
      if (pageToken == null) {
        return voidedPurchases;
      }
    }
    log.warn("[refund recheck] google voided list truncated : pages={}", VOIDED_MAX_PAGES);
    return voidedPurchases;
  }

  @Override
  public Set<String> findRefundedOrderIds(String packageName, Collection<String> orderIds, String serviceAccountJson) {
    List<String> orderIdList = List.copyOf(orderIds);
    Set<String> refundedOrderIds = new HashSet<>();
    // 주문 100건씩 나눠 조회
    for (int from = 0; from < orderIdList.size(); from += ORDER_BATCH_SIZE) {
      StringBuilder uri = new StringBuilder(API_BASE_URL + encode(packageName) + "/orders:batchGet?");
      for (String orderId : orderIdList.subList(from, Math.min(from + ORDER_BATCH_SIZE, orderIdList.size()))) {
        uri.append("orderIds=").append(encode(orderId)).append('&');
      }
      JsonNode body = getJson(URI.create(uri.substring(0, uri.length() - 1)), "orders.batchGet", serviceAccountJson);
      for (JsonNode order : body.path("orders")) {
        String orderId = textOrNull(order.path("orderId"));
        if (orderId != null && ORDER_STATE_REFUNDED.equals(order.path("state").asText(""))) {
          refundedOrderIds.add(orderId);
        }
      }
    }
    return refundedOrderIds;
  }

  // 목록 조회 GET: 200 > JSON, 그 밖은 확인 중 (목록 API 라 없는 토큰 개념 없음)
  private JsonNode getJson(URI uri, String operation, String serviceAccountJson) {
    HttpResponse<String> response = send(authorized(HttpRequest.newBuilder(uri), serviceAccountJson).GET().build());
    if (response.statusCode() != HTTP_OK) {
      throw unavailable(operation, response.statusCode());
    }
    try {
      return DefaultJsonMapper.SHARED.readTree(response.body());
    } catch (IOException e) {
      throw new StoreTemporarilyUnavailableException("google response unreadable", e);
    }
  }

  private static String textOrNull(JsonNode node) {
    return node.isTextual() && !node.asText().isBlank() ? node.asText() : null;
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
