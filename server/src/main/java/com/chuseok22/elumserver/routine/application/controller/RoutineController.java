package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineReviseRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
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
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
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

  @LogMonitoring(logParameters = false, logResult = true, logExecutionTime = true)
  @GetMapping("/suggestions")
  public ResponseEntity<List<RoutineSuggestionResponse>> getSuggestions() {
    List<RoutineSuggestionResponse> responses = routineService.getSuggestions();
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

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/revise")
  public ResponseEntity<RoutineResponse> revise(
    Authentication authentication,
    @PathVariable String routineId,
    @RequestBody @Valid RoutineReviseRequest request
  ) {
    RoutineResponse response = routineService.revise(authentication.getName(), routineId, request);
    return ResponseEntity.ok(response);
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

  // description은 보호자가 직접 입력하는 자유 텍스트라 민감정보가 포함될 수 있고,
  // RoutineResponse에도 rawInputText(마스킹 전 원문)가 포함되므로 logParameters/logResult를
  // 모두 false로 둔다(fable5 검토에서 발견).
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}")
  public ResponseEntity<RoutineResponse> updateStepDescription(
    Authentication authentication,
    @PathVariable String routineId,
    @PathVariable String stepId,
    @RequestBody @Valid RoutineStepUpdateRequest request
  ) {
    RoutineResponse response =
      routineService.updateStepDescription(authentication.getName(), routineId, stepId, request);
    return ResponseEntity.ok(response);
  }
}
