package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineExampleCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineAuthorResolver;
import com.chuseok22.elumserver.routine.application.service.RoutineExampleService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import com.chuseok22.logging.annotation.LogMonitoring;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 온보딩 예시 일과 API (#803): 고른 분류 > 예시 일과 생성 (AI 호출 없음)
 */
@RequestMapping("/api/routines/examples")
@RestController
@RequiredArgsConstructor
public class RoutineExampleController implements RoutineExampleControllerDocs {

  private final RoutineExampleService routineExampleService;
  private final RoutineAuthorResolver routineAuthorResolver;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping
  public ResponseEntity<List<RoutineResponse>> createExamples(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody RoutineExampleCreateRequest request
  ) {
    Caller caller = Caller.from(authentication, profileId);
    List<RoutineResponse> responses = routineExampleService.create(caller, request.categories());
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, responses));
  }
}
