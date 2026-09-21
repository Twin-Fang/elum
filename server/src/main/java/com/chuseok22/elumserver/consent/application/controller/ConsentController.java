package com.chuseok22.elumserver.consent.application.controller;

import com.chuseok22.elumserver.consent.application.dto.response.ConsentDocumentResponse;
import com.chuseok22.elumserver.consent.application.dto.response.ConsentDocumentsResponse;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 약관 전문을 준다 (이슈 #278).
 *
 * <p><b>인증이 없다.</b> 가입하기 전에 읽는 문서라 로그인을 요구할 수 없다.
 */
@RestController
@RequiredArgsConstructor
public class ConsentController implements ConsentControllerDocs {

  private final ConsentDocumentService consentDocumentService;

  @Override
  @LogMonitoring(logParameters = true, logExecutionTime = true)
  @GetMapping("/api/consents/documents")
  public ResponseEntity<ConsentDocumentsResponse> documents() {
    return ResponseEntity.ok(new ConsentDocumentsResponse(
      consentDocumentService.bundleVersion(),
      consentDocumentService.getAll().stream().map(ConsentDocumentResponse::from).toList()
    ));
  }
}
