package com.chuseok22.elumserver.consent.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.consent.application.dto.response.ConsentDocumentsResponse;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.PublishedConsents;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * 약관 응답 계약 (#531): 기존 필드 유지 + 대체 표시(locale, isFallbackLocale) + Content-Language
 */
class ConsentControllerLocaleTest {

  private final ConsentDocumentService consentDocumentService = mock(ConsentDocumentService.class);
  private final ConsentController controller = new ConsentController(consentDocumentService);

  @Test
  @DisplayName("대체된 응답은 JSON 에 locale·isFallbackLocale 를 싣고 Content-Language 가 실제 언어다 — 앱이 대체를 알아챌 수 있게")
  void fallbackResponse_exposesServedLocale() {
    when(consentDocumentService.getPublished(AppLocale.EN))
      .thenReturn(new PublishedConsents(AppLocale.KO, true, "2026-09-21", List.of()));

    ResponseEntity<ConsentDocumentsResponse> response =
      CurrentLocale.callAs(AppLocale.EN, controller::documents);
    JsonNode json = JsonMapper.builder().build().valueToTree(response.getBody());

    assertThat(response.getHeaders().getFirst(HttpHeaders.CONTENT_LANGUAGE)).isEqualTo("ko");
    assertThat(json.get("locale").asString()).isEqualTo("ko");
    assertThat(json.get("isFallbackLocale").asBoolean()).isTrue();
    // 옛 앱이 읽는 필드는 그대로
    assertThat(json.get("version").asString()).isEqualTo("2026-09-21");
    assertThat(json.has("documents")).isTrue();
  }
}
