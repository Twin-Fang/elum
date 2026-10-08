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
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineAuthorResolver;
import com.chuseok22.elumserver.routine.application.service.RoutineCreateService;
import com.chuseok22.elumserver.routine.application.service.RoutineProgressService;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService;
import com.chuseok22.elumserver.routine.application.service.RoutineService;
import com.chuseok22.elumserver.routine.application.service.RoutineStepPhotoService;
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
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RequestMapping("/api/routines")
@RestController
@RequiredArgsConstructor
public class RoutineController implements RoutineControllerDocs {

  private final RoutineService routineService;
  private final RoutineCreateService routineCreateService;
  private final RoutineQueryService routineQueryService;
  private final RoutineProgressService routineProgressService;
  private final RoutineStepPhotoService routineStepPhotoService;
  // 원문 가리기와 만든 사람 정보를 모든 일과 응답에 같은 방식으로 입힌다.
  private final RoutineAuthorResolver routineAuthorResolver;

  // rawInputText에 민감정보 원문이 포함될 수 있으므로 logParameters/logResult를 false로 둔다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping
  public ResponseEntity<RoutineResponse> create(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    // 크레딧 멱등 키. 구버전 앱은 보내지 않는다 — 서비스가 새로 만든다.
    @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
    @RequestBody @Valid RoutineCreateRequest request
  ) {
    Caller caller = Caller.from(authentication, profileId);
    RoutineResponse response = routineCreateService.create(caller, request, idempotencyKey);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }

  // rawInputText에 민감정보 원문이 포함될 수 있으므로 logParameters를 false로 둔다.
  // AI 가 실패해도 200을 반환한다(RoutineCreateService.generateQuestion 참고). 크레딧 부족만 403 이다.
  @LogMonitoring(logParameters = false, logResult = true, logExecutionTime = true)
  @PostMapping("/questions")
  public ResponseEntity<RoutineQuestionResponse> generateQuestion(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody @Valid RoutineQuestionRequest request
  ) {
    RoutineQuestionResponse response =
      routineCreateService.generateQuestion(Caller.from(authentication, profileId), request);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/{routineId}")
  public ResponseEntity<RoutineResponse> getRoutine(
    Authentication authentication, @PathVariable String routineId
  ) {
    Caller caller = Caller.from(authentication);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineQueryService.getRoutine(caller, routineId)));
  }

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<List<RoutineResponse>> getMyRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    Caller caller = Caller.from(authentication, profileId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineQueryService.getMyRoutines(caller)));
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/today")
  public ResponseEntity<List<RoutineResponse>> getTodayRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    Caller caller = Caller.from(authentication, profileId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineQueryService.getTodayRoutines(caller)));
  }

  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @GetMapping("/suggestions")
  public ResponseEntity<List<RoutineSuggestionResponse>> getSuggestions(
    @RequestParam(defaultValue = "4") int count
  ) {
    List<RoutineSuggestionResponse> responses = routineQueryService.getSuggestions(count);
    return ResponseEntity.ok(responses);
  }

  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/{routineId}/steps/{stepId}/image")
  public ResponseEntity<byte[]> getStepImage(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineImageStorage.ImageContent content =
      routineQueryService.getStepImage(Caller.from(authentication), routineId, stepId);
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
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineService.updateReward(caller, routineId, request);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
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
    List<RecentRewardResponse> response = routineQueryService.getRecentRewards(Caller.from(authentication, profileId));
    return ResponseEntity.ok(response);
  }

  @LogMonitoring
  @GetMapping("/past")
  public ResponseEntity<List<RoutineResponse>> getPastRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    Caller caller = Caller.from(authentication, profileId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineQueryService.getPastRoutines(caller)));
  }

  @LogMonitoring
  @GetMapping("/drafts")
  public ResponseEntity<List<RoutineResponse>> getDraftRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    Caller caller = Caller.from(authentication, profileId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineQueryService.getDraftRoutines(caller)));
  }

  // AI를 호출하지 않는다. 같은 카드로 오늘 일과를 하나 더 만드는 것뿐이다.
  @LogMonitoring
  @PostMapping("/{routineId}/duplicate")
  public ResponseEntity<RoutineResponse> duplicate(
    Authentication authentication, @PathVariable String routineId
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineService.duplicate(caller, routineId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
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
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineService.confirm(caller, routineId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}/complete")
  public ResponseEntity<RoutineResponse> completeStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    Caller caller = Caller.from(authentication);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineProgressService.completeStep(caller, routineId, stepId)));
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}/cancel")
  public ResponseEntity<RoutineResponse> cancelStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    Caller caller = Caller.from(authentication);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineProgressService.cancelStep(caller, routineId, stepId)));
  }

  // 오프라인 퍼스트 동기화 — 완료 집합을 통째로 받아 멱등 반영한다.
  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @PutMapping("/{routineId}/progress")
  public ResponseEntity<RoutineResponse> syncProgress(
    Authentication authentication,
    @PathVariable String routineId,
    @RequestBody RoutineProgressSyncRequest request
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineProgressService.syncProgress(caller, routineId, request.completedStepIdsOrEmpty());
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }

  // 보호자가 카드를 한 장 직접 추가한다.
  // title/description이 자유 텍스트라 민감정보가 섞일 수 있고, RoutineResponse에도
  // rawInputText(마스킹 전 원문)가 들어가므로 파라미터·결과 모두 로그에서 뺀다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{routineId}/steps")
  public ResponseEntity<RoutineResponse> addStep(
    Authentication authentication,
    @PathVariable String routineId,
    @RequestBody @Valid RoutineStepCreateRequest request
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineService.addStep(caller, routineId, request);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }

  // title/description은 보호자가 직접 입력하는 자유 텍스트라 민감정보가 포함될 수 있고,
  // RoutineResponse에도 rawInputText(마스킹 전 원문)가 포함되므로 logParameters/logResult를
  // 모두 false로 둔다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/steps/{stepId}")
  public ResponseEntity<RoutineResponse> updateStep(
    Authentication authentication,
    @PathVariable String routineId,
    @PathVariable String stepId,
    @RequestBody @Valid RoutineStepUpdateRequest request
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineService.updateStep(caller, routineId, stepId, request);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }

  // 카드 그림을 보호자가 찍은 사진으로 바꾼다. AI·크레딧을 쓰지 않는다.
  // 파일 바이트를 로그에 남기지 않도록 파라미터·결과 모두 뺀다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping(value = "/{routineId}/steps/{stepId}/image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public ResponseEntity<RoutineStepResponse> replaceStepImage(
    Authentication authentication,
    @PathVariable String routineId,
    @PathVariable String stepId,
    @RequestPart("image") MultipartFile image
  ) {
    RoutineStepResponse response =
      routineStepPhotoService.replaceStepImage(Caller.from(authentication), routineId, stepId, image);
    return ResponseEntity.ok(response);
  }

  // RoutineResponse에 rawInputText(마스킹 전 원문)가 포함되므로 logResult를 false로 둔다.
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{routineId}/steps/{stepId}")
  public ResponseEntity<RoutineResponse> deleteStep(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineService.deleteStep(caller, routineId, stepId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }
}
