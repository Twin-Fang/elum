package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryEnabledRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryLinesUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineMemoryService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 이룸이별 AI 메모 API (#1082, Pro): 보기 · 줄 바꾸기 · 켜기/끄기 · 모두 지우기
 * 메모 줄은 보호자가 쓴 글이라 요청·응답 본문을 로그에 남기지 않음
 */
@RequestMapping("/api/routine-memory")
@RestController
@RequiredArgsConstructor
public class RoutineMemoryController implements RoutineMemoryControllerDocs {

  private final RoutineMemoryService routineMemoryService;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<RoutineMemoryResponse> getMemory(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    return ResponseEntity.ok(routineMemoryService.get(Caller.from(authentication, profileId)));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping("/lines")
  public ResponseEntity<RoutineMemoryResponse> replaceLines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody RoutineMemoryLinesUpdateRequest request
  ) {
    return ResponseEntity.ok(routineMemoryService.replaceLines(Caller.from(authentication, profileId), request.lines()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/enabled")
  public ResponseEntity<RoutineMemoryResponse> setEnabled(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody RoutineMemoryEnabledRequest request
  ) {
    return ResponseEntity.ok(routineMemoryService.setEnabled(Caller.from(authentication, profileId), request.enabled()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping
  public ResponseEntity<RoutineMemoryResponse> clearMemory(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    return ResponseEntity.ok(routineMemoryService.clear(Caller.from(authentication, profileId)));
  }
}
