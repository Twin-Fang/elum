package com.chuseok22.elumserver.credit.application.controller;

import com.chuseok22.elumserver.credit.application.dto.response.CreditHistoryResponse;
import com.chuseok22.elumserver.credit.application.dto.response.CreditSummaryResponse;
import com.chuseok22.elumserver.credit.application.service.CreditHistoryService;
import com.chuseok22.elumserver.credit.application.service.CreditQueryService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/// 보호자 설정 화면의 AI 크레딧. 보호자 권한은 SecurityConfig 의 /api/** 기본 규칙(GUARDIAN)이 건다.
@RequestMapping("/api/credits")
@RestController
@RequiredArgsConstructor
public class CreditController implements CreditControllerDocs {

  private final CreditQueryService creditQueryService;
  private final CreditHistoryService creditHistoryService;

  // 숫자뿐이라 결과를 남겨도 된다 — 보호자가 "크레딧이 이상하다"고 할 때 그 시점 값을 로그로 대조한다.
  @LogMonitoring(logParameters = false, logResult = true, logExecutionTime = true)
  @GetMapping("/me")
  public ResponseEntity<CreditSummaryResponse> getMine(Authentication authentication) {
    return ResponseEntity.ok(creditQueryService.getMine(Caller.from(authentication).memberId()));
  }

  // 건별 내역은 일과 제목이 섞여 있어 결과를 남기지 않는다 (요청 쪽 / 크기만 남긴다)
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/ledger")
  public ResponseEntity<CreditHistoryResponse> getHistory(
    Authentication authentication,
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "" + CreditHistoryService.DEFAULT_PAGE_SIZE) int size
  ) {
    return ResponseEntity.ok(creditHistoryService.getMine(Caller.from(authentication).memberId(), page, size));
  }
}
