package com.chuseok22.elumserver.consent.application.controller;

import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.consent.application.dto.response.ConsentDocumentsResponse;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.PublishedConsents;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 약관 전문을 준다.
 *
 * <p><b>인증이 없다.</b> 가입하기 전에 읽는 문서라 로그인을 요구할 수 없다.
 */
@RestController
@RequiredArgsConstructor
public class ConsentController implements ConsentControllerDocs {

  private final ConsentDocumentService consentDocumentService;

  /** 요청 언어(Accept-Language) 게시본, 없으면 ko 대체 + 대체 표시 (#531) */
  @Override
  @LogMonitoring(logParameters = true, logExecutionTime = true)
  @GetMapping("/api/consents/documents")
  public ResponseEntity<ConsentDocumentsResponse> documents() {
    PublishedConsents published = consentDocumentService.getPublished(CurrentLocale.get());
    return ResponseEntity.ok()
      // 실제로 준 약관 언어 (요청 언어와 다를 수 있음)
      .header(HttpHeaders.CONTENT_LANGUAGE, published.locale().code())
      .body(ConsentDocumentsResponse.from(published));
  }
}
