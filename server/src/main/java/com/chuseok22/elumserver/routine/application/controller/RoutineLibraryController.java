package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineLibraryOrderRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineTitleUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineAuthorResolver;
import com.chuseok22.elumserver.routine.application.service.RoutineLibraryOrderService;
import com.chuseok22.elumserver.routine.application.service.RoutineLibraryService;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService;
import com.chuseok22.elumserver.routine.application.service.RoutineService;
import com.chuseok22.logging.annotation.LogMonitoring;
import java.util.List;
import lombok.RequiredArgsConstructor;
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
import org.springframework.web.bind.annotation.RestController;

/**
 * 일과관리 API (#804): 원본 목록, 칸 순서, 보내기, 복사하기, 목록에서 빼기, 제목 바꾸기
 */
@RequestMapping("/api/routines")
@RestController
@RequiredArgsConstructor
public class RoutineLibraryController implements RoutineLibraryDocs {

  private final RoutineService routineService;
  private final RoutineQueryService routineQueryService;
  private final RoutineLibraryService routineLibraryService;
  private final RoutineLibraryOrderService routineLibraryOrderService;
  // 원문 가리기와 만든 사람 정보를 모든 일과 응답에 같은 방식으로 입힌다.
  private final RoutineAuthorResolver routineAuthorResolver;

  // 일과관리 원본 목록 (#804). /{routineId} 보다 구체적인 경로라 먼저 잡힌다
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/library")
  public ResponseEntity<List<RoutineResponse>> getLibraryRoutines(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    Caller caller = Caller.from(authentication, profileId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineQueryService.getLibraryRoutines(caller)));
  }

  // 일과관리 칸 순서 저장: 낱개 일과 + 묶음을 한 줄로 (#844)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping("/library/order")
  public ResponseEntity<Void> reorderLibrary(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody RoutineLibraryOrderRequest request
  ) {
    routineLibraryOrderService.reorder(Caller.from(authentication, profileId), request == null ? null : request.cells());
    return ResponseEntity.noContent().build();
  }

  // 원본 카드로 오늘 일과를 만든다. AI 호출 없음, 원본 하나당 하루 한 번 (#804)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{routineId}/send")
  public ResponseEntity<RoutineResponse> send(
    Authentication authentication, @PathVariable String routineId
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineLibraryService.send(caller, routineId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }

  // 일과관리에만 있는 새 원본을 만든다. 홈에는 뜨지 않음 (#804)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{routineId}/copy")
  public ResponseEntity<RoutineResponse> copy(
    Authentication authentication, @PathVariable String routineId
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineLibraryService.copy(caller, routineId);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }

  // 일과관리 목록에서만 뺀다. 기록 없는 복사본만 실제로 지움 (#804)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{routineId}/library")
  public ResponseEntity<Void> removeFromLibrary(
    Authentication authentication, @PathVariable String routineId
  ) {
    routineLibraryService.removeFromLibrary(Caller.from(authentication), routineId);
    return ResponseEntity.noContent().build();
  }

  // 제목은 보호자 자유 입력이라 파라미터·결과를 로그에 남기지 않는다 (#804)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/{routineId}/title")
  public ResponseEntity<RoutineResponse> updateTitle(
    Authentication authentication, @PathVariable String routineId,
    @RequestBody RoutineTitleUpdateRequest request
  ) {
    Caller caller = Caller.from(authentication);
    RoutineResponse response = routineService.rename(caller, routineId, request == null ? null : request.title());
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, response));
  }
}
