package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineProgressSyncRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineReorderRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepReorderRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RecentRewardResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
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
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    // 크레딧 멱등 키(#407). 구버전 앱은 보내지 않는다 — 서비스가 새로 만든다.
    @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
    @RequestBody @Valid RoutineCreateRequest request
  ) {
    RoutineResponse response =
      routineService.create(Caller.from(authentication, profileId), request, idempotencyKey);
    return ResponseEntity.ok(response);
  }

  // rawInputText에 민감정보 원문이 포함될 수 있으므로 logParameters를 false로 둔다.
  // AI 가 실패해도 200을 반환한다(RoutineService.generateQuestion 참고). 크레딧 부족만 403 이다 (#407).
  @LogMonitoring(logParameters = false, logResult = true, logExecutionTime = true)
  @PostMapping("/questions")
  public ResponseEntity<RoutineQuestionResponse> generateQuestion(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody @Valid RoutineQuestionRequest request
  ) {
    RoutineQuestionResponse response =
      routineService.generateQuestion(Caller.from(authentication, profileId), request);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/{routineId}")
  public ResponseEntity<RoutineResponse> getRoutine(
    Authentication authentication, @PathVariable String routineId
  ) {
    RoutineResponse response = routineService.getRoutine(Caller.from(authentication), routineId);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<List<RoutineResponse>> getMyRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    List<RoutineResponse> responses = routineService.getMyRoutines(Caller.from(authentication, profileId));
    return ResponseEntity.ok(responses);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/today")
  public ResponseEntity<List<RoutineResponse>> getTodayRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    List<RoutineResponse> responses = routineService.getTodayRoutines(Caller.from(authentication, profileId));
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
      routineService.getStepImage(Caller.from(authentication), routineId, stepId);
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
    RoutineResponse response = routineService.updateReward(Caller.from(authentication), routineId, request);
    return ResponseEntity.ok(response);
  }

  // 화면에 보이는 순서를 그대로 받는다. 부분 갱신이 아니라 전체 교체다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/order")
  public ResponseEntity<Void> reorder(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody RoutineReorderRequest request
  ) {
    routineService.reorder(Caller.from(authentication, profileId), request.routineIds());
    return ResponseEntity.noContent().build();
  }

  // 일과 순서(/order)와 같은 방식이다. 화면에 보이는 단계 전체를 그대로 받는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/order")
  public ResponseEntity<Void> reorderSteps(
    Authentication authentication, @PathVariable String routineId,
    @RequestBody RoutineStepReorderRequest request
  ) {
    routineService.reorderSteps(Caller.from(authentication), routineId, request.stepIds());
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/recent-rewards")
  public ResponseEntity<List<RecentRewardResponse>> getRecentRewards(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    List<RecentRewardResponse> response = routineService.getRecentRewards(Caller.from(authentication, profileId));
    return ResponseEntity.ok(response);
  }

  @LogMonitoring
  @GetMapping("/past")
  public ResponseEntity<List<RoutineResponse>> getPastRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    List<RoutineResponse> response = routineService.getPastRoutines(Caller.from(authentication, profileId));
    return ResponseEntity.ok(response);
  }

  @LogMonitoring
  @GetMapping("/drafts")
  public ResponseEntity<List<RoutineResponse>> getDraftRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    List<RoutineResponse> response = routineService.getDraftRoutines(Caller.from(authentication, profileId));
    return ResponseEntity.ok(response);
  }

  // AI를 호출하지 않는다. 같은 카드로 오늘 일과를 하나 더 만드는 것뿐이다.
  @LogMonitoring
  @PostMapping("/{routineId}/duplicate")
  public ResponseEntity<RoutineResponse> duplicate(
    Authentication authentication, @PathVariable String routineId
  ) {
    RoutineResponse response = routineService.duplicate(Caller.from(authentication), routineId);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring
  @DeleteMapping("/{routineId}")
  public ResponseEntity<Void> delete(
    Authentication authentication, @PathVariable String routineId
  ) {
    routineService.delete(Caller.from(authentication), routineId);
    return ResponseEntity.noContent().build();
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/confirm")
  public ResponseEntity<RoutineResponse> confirm(
    Authentication authentication, @PathVariable String routineId
  ) {
    RoutineResponse response = routineService.confirm(Caller.from(authentication), routineId);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}/complete")
  public ResponseEntity<RoutineResponse> completeStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineResponse response = routineService.completeStep(Caller.from(authentication), routineId, stepId);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}/cancel")
  public ResponseEntity<RoutineResponse> cancelStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineResponse response = routineService.cancelStep(Caller.from(authentication), routineId, stepId);
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
      Caller.from(authentication), routineId, request.completedStepIdsOrEmpty()
    );
    return ResponseEntity.ok(response);
  }

  // 보호자가 카드를 한 장 직접 추가한다 (이슈 #199).
  // title/description이 자유 텍스트라 민감정보가 섞일 수 있고, RoutineResponse에도
  // rawInputText(마스킹 전 원문)가 들어가므로 파라미터·결과 모두 로그에서 뺀다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{routineId}/steps")
  public ResponseEntity<RoutineResponse> addStep(
    Authentication authentication,
    @PathVariable String routineId,
    @RequestBody @Valid RoutineStepCreateRequest request
  ) {
    RoutineResponse response =
      routineService.addStep(Caller.from(authentication), routineId, request);
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
      routineService.updateStep(Caller.from(authentication), routineId, stepId, request);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{routineId}/steps/{stepId}")
  public ResponseEntity<RoutineResponse> deleteStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineResponse response = routineService.deleteStep(Caller.from(authentication), routineId, stepId);
    return ResponseEntity.ok(response);
  }
}
