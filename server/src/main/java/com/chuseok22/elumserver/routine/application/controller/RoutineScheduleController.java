package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineScheduleSaveRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineScheduleListResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineScheduleResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineScheduleService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 요일별 반복 일과 API (#782, #1080): 주간 계획 조회, 요일·시각 저장(Pro), 끄기
 * 보호자만 (이룸이 휴대폰은 SecurityConfig anyRequest 에서 막힘)
 */
@RequestMapping("/api/routine-schedules")
@RestController
@RequiredArgsConstructor
public class RoutineScheduleController implements RoutineScheduleDocs {

  private final RoutineScheduleService routineScheduleService;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<RoutineScheduleListResponse> getSchedules(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    return ResponseEntity.ok(routineScheduleService.list(Caller.from(authentication, profileId)));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping("/{routineId}")
  public ResponseEntity<RoutineScheduleResponse> save(
    Authentication authentication, @PathVariable String routineId, @RequestBody RoutineScheduleSaveRequest request
  ) {
    return ResponseEntity.ok(routineScheduleService.save(Caller.from(authentication), routineId, request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{routineId}")
  public ResponseEntity<Void> delete(Authentication authentication, @PathVariable String routineId) {
    routineScheduleService.delete(Caller.from(authentication), routineId);
    return ResponseEntity.noContent().build();
  }
}
