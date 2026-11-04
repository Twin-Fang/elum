package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineTranslateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineAuthorResolver;
import com.chuseok22.elumserver.routine.application.service.RoutineTranslateService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 다른 언어로 만들기 API (#1077): 글만 번역한 새 원본을 일과관리에 (그림 재사용, 글 크레딧, Pro)
 */
@RequestMapping("/api/routines")
@RestController
@RequiredArgsConstructor
public class RoutineTranslateController implements RoutineTranslateControllerDocs {

  private final RoutineTranslateService routineTranslateService;
  private final RoutineAuthorResolver routineAuthorResolver;

  // 카드 글이 응답에 실려 파라미터·결과를 로그에 남기지 않는다
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{routineId}/translate")
  public ResponseEntity<RoutineResponse> translate(
    Authentication authentication, @PathVariable String routineId,
    @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
    @RequestBody(required = false) RoutineTranslateRequest request
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineTranslateService.translate(
      caller, routineId, request == null ? null : request.language(), idempotencyKey);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }
}
