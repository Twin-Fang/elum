package com.chuseok22.elumserver.adreward.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.adreward.infrastructure.client.AdSsvRelayClient;
import com.chuseok22.elumserver.adreward.infrastructure.client.AdSsvRelayClient.RelayResponse;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.net.URI;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.ResponseEntity;

/**
 * 이전 잠금 중 광고 보상 콜백 전달 (#1053)
 * 깨지면: 전환 동안 본 광고 보상이 사라지거나(쿼리가 바뀌면 새 서버 서명 검증 실패), 두 서버가 콜백을 서로 넘긴다
 */
class AdSsvRelayServiceTest {

  private static final String NEW_SERVER = "https://api.elum.suhsaechan.kr";
  // 서명이 붙은 원문 쿼리 (퍼센트 인코딩 그대로여야 한다)
  private static final String RAW_QUERY =
    "ad_network=5450213213286189855&key_id=3335741209&signature=MEUCIQ%2B%2F&user_id=a%3Ab";

  private final MigrationLock migrationLock = mock(MigrationLock.class);
  private final AdSsvRelayClient client = mock(AdSsvRelayClient.class);
  private final AdSsvRelayService service = new AdSsvRelayService(migrationLock, client);

  @Test
  @DisplayName("새 서버 주소가 없으면 503 (Google 이 다시 보낸다)")
  void relay_noBaseUrl_returns503() {
    when(migrationLock.newServerBaseUrl()).thenReturn(Optional.empty());

    assertThat(service.relay(RAW_QUERY, false).getStatusCode().value()).isEqualTo(503);
    verify(client, never()).forward(any());
  }

  @Test
  @DisplayName("이미 전달된 콜백은 다시 넘기지 않고 503")
  void relay_alreadyRelayed_returns503() {
    when(migrationLock.newServerBaseUrl()).thenReturn(Optional.of(NEW_SERVER));

    assertThat(service.relay(RAW_QUERY, true).getStatusCode().value()).isEqualTo(503);
    verify(client, never()).forward(any());
  }

  @Test
  @DisplayName("원문 쿼리를 다시 인코딩하지 않고 그대로 넘기고, 새 서버 응답을 그대로 돌려준다")
  void relay_forwardsRawQueryExactly() {
    when(migrationLock.newServerBaseUrl()).thenReturn(Optional.of(NEW_SERVER));
    when(client.forward(any())).thenReturn(new RelayResponse(200, "ok"));

    ResponseEntity<String> response = service.relay(RAW_QUERY, false);

    ArgumentCaptor<URI> target = ArgumentCaptor.forClass(URI.class);
    verify(client).forward(target.capture());
    assertThat(target.getValue().toString()).isEqualTo(NEW_SERVER + "/api/ads/ssv?" + RAW_QUERY);
    assertThat(target.getValue().getRawQuery()).isEqualTo(RAW_QUERY);
    assertThat(response.getStatusCode().value()).isEqualTo(200);
    assertThat(response.getBody()).isEqualTo("ok");
  }

  @Test
  @DisplayName("새 서버가 거절(400)하면 그 응답을 그대로")
  void relay_newServerRejects_passesStatus() {
    when(migrationLock.newServerBaseUrl()).thenReturn(Optional.of(NEW_SERVER));
    when(client.forward(any())).thenReturn(new RelayResponse(400, "invalid"));

    assertThat(service.relay(RAW_QUERY, false).getStatusCode().value()).isEqualTo(400);
  }

  @Test
  @DisplayName("새 서버에 닿지 못하면 503")
  void relay_clientFails_returns503() {
    when(migrationLock.newServerBaseUrl()).thenReturn(Optional.of(NEW_SERVER));
    when(client.forward(any())).thenThrow(new IllegalStateException("connect"));

    assertThat(service.relay(RAW_QUERY, false).getStatusCode().value()).isEqualTo(503);
  }
}
