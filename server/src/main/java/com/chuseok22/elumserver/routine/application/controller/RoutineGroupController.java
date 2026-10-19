package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineGroupCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineGroupNameUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineGroupRoutinesUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineGroupResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineAuthorResolver;
import com.chuseok22.elumserver.routine.application.service.RoutineGroupService;
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
 * 일과관리 묶음 API (#806). 보호자만 (이룸이 휴대폰은 SecurityConfig 에서 막힘)
 * 묶음 이름은 보호자 자유 입력이라 파라미터·결과를 로그에 남기지 않음
 */
@RequestMapping("/api/routine-groups")
@RestController
@RequiredArgsConstructor
public class RoutineGroupController implements RoutineGroupDocs {

  private final RoutineGroupService routineGroupService;
  // 묶음째 보내기 응답도 일과 응답과 같은 방식(원문 가리기·만든 사람)으로 입힘
  private final RoutineAuthorResolver routineAuthorResolver;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<List<RoutineGroupResponse>> getGroups(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    return ResponseEntity.ok(routineGroupService.getGroups(Caller.from(authentication, profileId)));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping
  public ResponseEntity<RoutineGroupResponse> create(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody RoutineGroupCreateRequest request
  ) {
    return ResponseEntity.ok(routineGroupService.create(Caller.from(authentication, profileId),
      request == null ? null : request.name(), request == null ? null : request.routineIds()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/{groupId}/name")
  public ResponseEntity<RoutineGroupResponse> rename(
    Authentication authentication, @PathVariable String groupId,
    @RequestBody RoutineGroupNameUpdateRequest request
  ) {
    return ResponseEntity.ok(routineGroupService.rename(Caller.from(authentication), groupId,
      request == null ? null : request.name()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping("/{groupId}/routines")
  public ResponseEntity<RoutineGroupResponse> replaceRoutines(
    Authentication authentication, @PathVariable String groupId,
    @RequestBody RoutineGroupRoutinesUpdateRequest request
  ) {
    return ResponseEntity.ok(routineGroupService.replaceRoutines(Caller.from(authentication), groupId,
      request == null ? null : request.routineIds()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{groupId}")
  public ResponseEntity<Void> delete(Authentication authentication, @PathVariable String groupId) {
    routineGroupService.delete(Caller.from(authentication), groupId);
    return ResponseEntity.noContent().build();
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{groupId}/copy")
  public ResponseEntity<RoutineGroupResponse> copy(Authentication authentication, @PathVariable String groupId) {
    return ResponseEntity.ok(routineGroupService.copy(Caller.from(authentication), groupId));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{groupId}/send")
  public ResponseEntity<List<RoutineResponse>> send(Authentication authentication, @PathVariable String groupId) {
    Caller caller = Caller.from(authentication);
    return ResponseEntity.ok(routineAuthorResolver.forCaller(caller, routineGroupService.send(caller, groupId)));
  }
}
