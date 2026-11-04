package com.chuseok22.elumserver.expertroutine.application.controller;

import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineImportRequest;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineDetailResponse;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineImportResponse;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineSummaryResponse;
import com.chuseok22.elumserver.expertroutine.application.service.ExpertRoutineImportService;
import com.chuseok22.elumserver.expertroutine.application.service.ExpertRoutineQueryService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.logging.annotation.LogMonitoring;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/// 전문가 일과: 목록·미리 보기는 보호자 누구나, 가져오기는 ROUTINE_TEMPLATES 권한. 보호자 권한은 SecurityConfig /api/** 기본 규칙(GUARDIAN)
@RequestMapping("/api/expert-routines")
@RestController
@RequiredArgsConstructor
public class ExpertRoutineController implements ExpertRoutineControllerDocs {

  private final ExpertRoutineQueryService expertRoutineQueryService;
  private final ExpertRoutineImportService expertRoutineImportService;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping
  public ResponseEntity<List<ExpertRoutineSummaryResponse>> getList(
    @RequestParam(required = false) String category,
    @RequestParam(required = false) String language
  ) {
    return ResponseEntity.ok(expertRoutineQueryService.list(category, language, CurrentLocale.get()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/{expertRoutineId}")
  public ResponseEntity<ExpertRoutineDetailResponse> getDetail(@PathVariable String expertRoutineId) {
    return ResponseEntity.ok(expertRoutineQueryService.detail(expertRoutineId));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{expertRoutineId}/import")
  public ResponseEntity<ExpertRoutineImportResponse> importToLibrary(
    Authentication authentication,
    @PathVariable String expertRoutineId,
    @RequestBody ExpertRoutineImportRequest request
  ) {
    return ResponseEntity.ok(
      expertRoutineImportService.importToLibrary(Caller.from(authentication), expertRoutineId, request));
  }
}
