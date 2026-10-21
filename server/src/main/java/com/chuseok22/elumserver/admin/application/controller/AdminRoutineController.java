package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineAiJobs;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStepImage;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.format.AdminLogIds;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminRoutineList;
import com.chuseok22.elumserver.admin.application.service.AdminRoutineAiJobService;
import com.chuseok22.elumserver.admin.application.service.AdminRoutineService;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;

@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminRoutineController {

  private final AdminRoutineService adminRoutineService;
  private final AdminRoutineAiJobService adminRoutineAiJobService;
  private final AdminDateFormatter adminDateFormatter;

  /// 일과 목록: 검색어(q), 필터(AdminRoutineList 정의 4개), 정렬(sort), 페이지(page, 1부터). 허용 밖 값은 보정된다
  @GetMapping("/admin/routines")
  public String list(@RequestParam Map<String, String> parameters, Model model) {
    AdminListQuery query = AdminListQuery.fromParameters(parameters, AdminRoutineList.DEFINITION);

    Page<AdminRoutineResponse> routines = adminRoutineService.search(query);
    model.addAttribute("routines", routines);
    model.addAttribute("rows", routines.getContent().stream()
      .map(routine -> AdminRoutineList.toRow(routine, adminDateFormatter)).toList());
    model.addAttribute("definition", AdminRoutineList.DEFINITION);
    model.addAttribute("query", query);
    // 페이저 링크가 검색·필터·정렬을 유지하도록 (page 는 페이저가 붙임)
    model.addAttribute("pagerBaseUrl", "/admin/routines" + query.toQueryString(query.sort(), 1));
    return "admin/routines";
  }

  /// 일과 상세: 일과·단계 + 이 일과의 AI 작업 카드 (카드 조회 실패는 카드만 안내)
  @GetMapping("/admin/routines/{id}")
  public String detail(@PathVariable String id, Model model) {
    model.addAttribute("routine", adminRoutineService.getDetail(id));
    model.addAttribute("aiJobs", aiJobsOrLoadFailed(id));
    return "admin/routine-detail";
  }

  @GetMapping("/admin/routines/{routineId}/steps/{stepId}/image")
  public ResponseEntity<byte[]> stepImage(@PathVariable String routineId, @PathVariable String stepId) {
    AdminRoutineStepImage image = adminRoutineService.getStepImage(routineId, stepId);
    return ResponseEntity.ok()
      .contentType(MediaType.parseMediaType(image.contentType()))
      .body(image.bytes());
  }

  // AI 작업 카드 조회 실패는 카드에 에러 코드만 보이고 일과 상세는 그대로
  private AdminRoutineAiJobs aiJobsOrLoadFailed(String routineId) {
    try {
      return adminRoutineAiJobService.loadAiJobsOf(routineId);
    } catch (RuntimeException e) {
      // routineId 는 주소에서 온 값이라 UUID 문자(16진수, -) 밖은 ? 로 바꿔 남김
      log.warn("[admin routines] ai jobs load failed : routineId={}, code={}",
        AdminLogIds.toLoggableId(routineId), AdminRoutineAiJobs.LOAD_FAILED_ERROR_CODE, e);
      return AdminRoutineAiJobs.loadFailed();
    }
  }
}
