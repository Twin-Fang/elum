package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportWeeksResponse;
import com.chuseok22.elumserver.routine.application.service.WeeklyReportService;
import com.chuseok22.logging.annotation.LogMonitoring;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 주간 리포트 API (#1074): 이룸이 한 주 완료 기록 요약 + AI 정리 글 (Pro), 볼 수 있는 주 목록
 */
@RequestMapping("/api/routines/weekly-report")
@RestController
@RequiredArgsConstructor
public class WeeklyReportController implements WeeklyReportControllerDocs {

  private final WeeklyReportService weeklyReportService;

  // 응답에 일과·카드 제목이 들어가 결과는 로그에 남기지 않음
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<WeeklyReportResponse> getWeeklyReport(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestParam(value = "weekStart", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate weekStart
  ) {
    Caller caller = Caller.from(authentication, profileId);
    return ResponseEntity.ok(weeklyReportService.getWeeklyReport(caller, weekStart));
  }

  // 주 목록은 일과·카드 제목이 없어 결과를 남겨도 되지만 위와 같은 규칙으로 맞춤
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/weeks")
  public ResponseEntity<WeeklyReportWeeksResponse> getRecordedWeeks(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    Caller caller = Caller.from(authentication, profileId);
    return ResponseEntity.ok(weeklyReportService.getRecordedWeeks(caller));
  }
}
