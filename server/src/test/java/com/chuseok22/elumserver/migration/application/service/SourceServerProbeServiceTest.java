package com.chuseok22.elumserver.migration.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.properties.MigrationProperties;
import com.chuseok22.elumserver.migration.application.dto.response.SourceServerProbeView;
import com.chuseok22.elumserver.migration.application.dto.response.SourceServerProbeView.State;
import com.chuseok22.elumserver.migration.infrastructure.client.SourceServerStatusClient;
import com.chuseok22.elumserver.migration.infrastructure.client.SourceServerStatusClient.SourceServerHttpResponse;
import java.net.http.HttpTimeoutException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.ResourceAccessException;

/**
 * 옛 서버 안내 상태 (#1062): 정상 안내, 응답 없음, 엉뚱한 주소 안내, 오류 상태 코드
 * 깨지면: 옛 서버가 앱을 새 서버로 보내지 않는데 화면은 정상으로 보이거나, 옛 서버가 죽으면 화면도 죽는다
 */
class SourceServerProbeServiceTest {

  private static final String SOURCE_BASE_URL = "https://api.elum.chuseok22.com";

  private final SourceServerStatusClient client = mock(SourceServerStatusClient.class);
  private final SourceServerProbeService service =
    new SourceServerProbeService(new MigrationProperties(null, SOURCE_BASE_URL + "/"), client);

  private static String statusBody(boolean isMaintenance, String apiBaseUrl) {
    String server = apiBaseUrl == null ? "null" : "{\"apiBaseUrl\":\"" + apiBaseUrl + "\"}";
    return "{\"maintenance\":" + isMaintenance + ",\"maintenanceMessage\":\"\",\"server\":" + server + "}";
  }

  @Test
  @DisplayName("옛 서버가 새 서버 주소를 안내하면 응답함 · 점검 아님 · 새 주소 안내 맞음")
  void announcingNewServer_isResponded() {
    when(client.fetchAppStatus(SOURCE_BASE_URL))
      .thenReturn(new SourceServerHttpResponse(200, statusBody(false, "https://api.elum.suhsaechan.kr")));

    SourceServerProbeView view = service.probe();

    assertThat(view.state()).isEqualTo(State.RESPONDED);
    assertThat(view.isMaintenance()).isFalse();
    assertThat(view.isAnnouncingNewServer()).isTrue();
  }

  @Test
  @DisplayName("3초 안에 응답이 없으면 화면은 뜨고 '응답 없음' + 원인 이름")
  void timeout_isUnreachable() {
    when(client.fetchAppStatus(SOURCE_BASE_URL))
      .thenThrow(new ResourceAccessException("I/O error", new HttpTimeoutException("request timed out")));

    SourceServerProbeView view = service.probe();

    assertThat(view.state()).isEqualTo(State.UNREACHABLE);
    assertThat(view.failureReason()).isEqualTo("HttpTimeoutException");
    assertThat(view.isAnnouncingNewServer()).isFalse();
  }

  @Test
  @DisplayName("옛 서버가 자기 주소나 빈 값을 안내하면 '새 주소 안내' 가 아님")
  void announcingOtherAddress_isNotNewServer() {
    when(client.fetchAppStatus(SOURCE_BASE_URL))
      .thenReturn(new SourceServerHttpResponse(200, statusBody(true, "https://api.elum.chuseok22.com")));

    SourceServerProbeView view = service.probe();

    assertThat(view.state()).isEqualTo(State.RESPONDED);
    assertThat(view.isMaintenance()).isTrue();
    assertThat(view.isAnnouncingNewServer()).isFalse();
  }

  @Test
  @DisplayName("오류 상태 코드(503 등)는 응답함으로 보이지 않고 상태 코드를 보여 준다")
  void errorStatus_isHttpError() {
    when(client.fetchAppStatus(SOURCE_BASE_URL)).thenReturn(new SourceServerHttpResponse(503, "busy"));

    SourceServerProbeView view = service.probe();

    assertThat(view.state()).isEqualTo(State.HTTP_ERROR);
    assertThat(view.httpStatus()).isEqualTo(503);
  }
}
