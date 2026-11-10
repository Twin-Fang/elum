package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryEnabledRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryImportRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryRuleCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryRuleUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryExportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryImportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryObservationResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineMemoryObservationService;
import com.chuseok22.elumserver.routine.application.service.RoutineMemoryPortabilityService;
import com.chuseok22.elumserver.routine.application.service.RoutineMemoryService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 이룸이별·보호자별 AI 메모리 API (Pro): 보기 · 규칙 추가/고치기/지우기 · 켜기/끄기 · 모두 지우기 · 방금 찾은 수정 · 내보내기/가져오기
 * 규칙은 보호자가 쓴 글이라 요청·응답 본문을 로그에 남기지 않음
 */
@RequestMapping("/api/routine-memory")
@RestController
@RequiredArgsConstructor
public class RoutineMemoryController implements RoutineMemoryControllerDocs {

  private final RoutineMemoryService routineMemoryService;
  private final RoutineMemoryObservationService routineMemoryObservationService;
  private final RoutineMemoryPortabilityService routineMemoryPortabilityService;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<RoutineMemoryResponse> getMemory(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    return ResponseEntity.ok(routineMemoryService.get(Caller.from(authentication, profileId)));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/rules")
  public ResponseEntity<RoutineMemoryResponse> addRule(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody RoutineMemoryRuleCreateRequest request
  ) {
    return ResponseEntity.ok(routineMemoryService.addRule(Caller.from(authentication, profileId), request.text()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/rules/{ruleId}")
  public ResponseEntity<RoutineMemoryResponse> updateRule(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @PathVariable String ruleId,
    @RequestBody RoutineMemoryRuleUpdateRequest request
  ) {
    return ResponseEntity.ok(routineMemoryService.updateRule(Caller.from(authentication, profileId), ruleId, request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/rules/{ruleId}")
  public ResponseEntity<RoutineMemoryResponse> deleteRule(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @PathVariable String ruleId
  ) {
    return ResponseEntity.ok(routineMemoryService.deleteRule(Caller.from(authentication, profileId), ruleId));
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

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/observations")
  public ResponseEntity<RoutineMemoryObservationResponse> getObservations(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestParam String routineId
  ) {
    return ResponseEntity.ok(
      routineMemoryObservationService.observationsOf(Caller.from(authentication, profileId), routineId));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/export")
  public ResponseEntity<RoutineMemoryExportResponse> exportMemory(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    return ResponseEntity.ok(routineMemoryPortabilityService.export(Caller.from(authentication, profileId)));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/import")
  public ResponseEntity<RoutineMemoryImportResponse> importMemory(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody RoutineMemoryImportRequest request
  ) {
    return ResponseEntity.ok(routineMemoryPortabilityService.importRules(Caller.from(authentication, profileId), request));
  }
}
