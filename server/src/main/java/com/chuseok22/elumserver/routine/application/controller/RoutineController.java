package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineProgressSyncRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RecentRewardResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.logging.annotation.LogMonitoring;
import org.springframework.http.MediaType;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RequestMapping("/api/routines")
@RestController
@RequiredArgsConstructor
public class RoutineController implements RoutineControllerDocs {

  private final RoutineService routineService;

  // rawInputText에 민감정보 원문이 포함될 수 있으므로 logParameters/logResult를 false로 둔다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping
  public ResponseEntity<RoutineResponse> create(
    Authentication authentication, @RequestBody @Valid RoutineCreateRequest request
  ) {
    RoutineResponse response = routineService.create(authentication.getName(), request);
    return ResponseEntity.ok(response);
  }

  // rawInputText에 민감정보 원문이 포함될 수 있으므로 logParameters를 false로 둔다.
  // 이 엔드포인트는 실패해도 항상 200을 반환한다(RoutineService.generateQuestion 참고).
  @LogMonitoring(logParameters = false, logResult = true, logExecutionTime = true)
  @PostMapping("/questions")
  public ResponseEntity<RoutineQuestionResponse> generateQuestion(
    Authentication authentication, @RequestBody @Valid RoutineQuestionRequest request
  ) {
    RoutineQuestionResponse response = routineService.generateQuestion(authentication.getName(), request);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/{routineId}")
  public ResponseEntity<RoutineResponse> getRoutine(
    Authentication authentication, @PathVariable String routineId
  ) {
    RoutineResponse response = routineService.getRoutine(authentication.getName(), routineId);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<List<RoutineResponse>> getMyRoutines(Authentication authentication) {
    List<RoutineResponse> responses = routineService.getMyRoutines(authentication.getName());
    return ResponseEntity.ok(responses);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/today")
  public ResponseEntity<List<RoutineResponse>> getTodayRoutines(Authentication authentication) {
    List<RoutineResponse> responses = routineService.getTodayRoutines(authentication.getName());
    return ResponseEntity.ok(responses);
  }

  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @GetMapping("/suggestions")
  public ResponseEntity<List<RoutineSuggestionResponse>> getSuggestions(
    @RequestParam(defaultValue = "4") int count
  ) {
    List<RoutineSuggestionResponse> responses = routineService.getSuggestions(count);
    return ResponseEntity.ok(responses);
  }

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/{routineId}/steps/{stepId}/image")
  public ResponseEntity<byte[]> getStepImage(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineImageStorage.ImageContent content =
      routineService.getStepImage(authentication.getName(), routineId, stepId);
    return ResponseEntity.ok()
      .contentType(MediaType.parseMediaType(content.contentType()))
      .body(content.bytes());
  }

  // 보상 텍스트는 보호자 자유 입력이라 민감정보가 섞일 수 있다 — 파라미터를 로그에 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/reward")
  public ResponseEntity<RoutineResponse> updateReward(
    Authentication authentication, @PathVariable String routineId,
    @RequestBody @Valid RewardUpdateRequest request
  ) {
    RoutineResponse response = routineService.updateReward(authentication.getName(), routineId, request);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/recent-rewards")
  public ResponseEntity<List<RecentRewardResponse>> getRecentRewards(Authentication authentication) {
    List<RecentRewardResponse> response = routineService.getRecentRewards(authentication.getName());
    return ResponseEntity.ok(response);
  }

  @LogMonitoring
  @GetMapping("/past")
  public ResponseEntity<List<RoutineResponse>> getPastRoutines(Authentication authentication) {
    List<RoutineResponse> response = routineService.getPastRoutines(authentication.getName());
    return ResponseEntity.ok(response);
  }

  @LogMonitoring
  @GetMapping("/drafts")
  public ResponseEntity<List<RoutineResponse>> getDraftRoutines(Authentication authentication) {
    List<RoutineResponse> response = routineService.getDraftRoutines(authentication.getName());
    return ResponseEntity.ok(response);
  }

  // AI를 호출하지 않는다. 같은 카드로 오늘 일과를 하나 더 만드는 것뿐이다.
  @LogMonitoring
  @PostMapping("/{routineId}/duplicate")
  public ResponseEntity<RoutineResponse> duplicate(
    Authentication authentication, @PathVariable String routineId
  ) {
    RoutineResponse response = routineService.duplicate(authentication.getName(), routineId);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring
  @DeleteMapping("/{routineId}")
  public ResponseEntity<Void> delete(
    Authentication authentication, @PathVariable String routineId
  ) {
    routineService.delete(authentication.getName(), routineId);
    return ResponseEntity.noContent().build();
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/confirm")
  public ResponseEntity<RoutineResponse> confirm(
    Authentication authentication, @PathVariable String routineId
  ) {
    RoutineResponse response = routineService.confirm(authentication.getName(), routineId);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}/complete")
  public ResponseEntity<RoutineResponse> completeStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineResponse response = routineService.completeStep(authentication.getName(), routineId, stepId);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}/cancel")
  public ResponseEntity<RoutineResponse> cancelStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineResponse response = routineService.cancelStep(authentication.getName(), routineId, stepId);
    return ResponseEntity.ok(response);
  }

  // 오프라인 퍼스트 동기화 — 완료 집합을 통째로 받아 멱등 반영한다 (이슈 #140).
  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PutMapping("/{routineId}/progress")
  public ResponseEntity<RoutineResponse> syncProgress(
    Authentication authentication,
    @PathVariable String routineId,
    @RequestBody RoutineProgressSyncRequest request
  ) {
    RoutineResponse response = routineService.syncProgress(
      authentication.getName(), routineId, request.completedStepIdsOrEmpty()
    );
    return ResponseEntity.ok(response);
  }

  // title/description은 보호자가 직접 입력하는 자유 텍스트라 민감정보가 포함될 수 있고,
  // RoutineResponse에도 rawInputText(마스킹 전 원문)가 포함되므로 logParameters/logResult를
  // 모두 false로 둔다(fable5 검토에서 발견).
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}")
  public ResponseEntity<RoutineResponse> updateStep(
    Authentication authentication,
    @PathVariable String routineId,
    @PathVariable String stepId,
    @RequestBody @Valid RoutineStepUpdateRequest request
  ) {
    RoutineResponse response =
      routineService.updateStep(authentication.getName(), routineId, stepId, request);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{routineId}/steps/{stepId}")
  public ResponseEntity<RoutineResponse> deleteStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineResponse response = routineService.deleteStep(authentication.getName(), routineId, stepId);
    return ResponseEntity.ok(response);
  }
}
