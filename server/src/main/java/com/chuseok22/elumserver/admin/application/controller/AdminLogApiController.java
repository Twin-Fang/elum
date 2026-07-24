package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.LogTailResponse;
import com.chuseok22.elumserver.admin.application.service.AdminLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// AdminPromptTestController와 같은 이유로 SSR 컨트롤러와 분리한다 — 이 엔드포인트는 화면의
// 폴링 fetch가 호출하므로 JSON 에러 응답이 필요해 GlobalExceptionHandler의 assignableTypes에 등록된다.
// @LogMonitoring은 일부러 붙이지 않는다: 2초 폴링이 그대로 로그 파일에 쌓여 로그를 로그가 덮는다.
@RestController
@RequiredArgsConstructor
public class AdminLogApiController {

  private final AdminLogService adminLogService;

  @GetMapping("/admin/logs/api/tail")
  public LogTailResponse tail(
    @RequestParam(required = false) Long offset,
    @RequestParam(required = false) Integer lines
  ) {
    return adminLogService.tail(offset, lines);
  }
}
