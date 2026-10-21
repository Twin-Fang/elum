package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStepImage;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminRoutineList;
import com.chuseok22.elumserver.admin.application.service.AdminRoutineService;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
@RequiredArgsConstructor
public class AdminRoutineController {

  private final AdminRoutineService adminRoutineService;
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

  @GetMapping("/admin/routines/{id}")
  public String detail(@PathVariable String id, Model model) {
    model.addAttribute("routine", adminRoutineService.getDetail(id));
    return "admin/routine-detail";
  }

  @GetMapping("/admin/routines/{routineId}/steps/{stepId}/image")
  public ResponseEntity<byte[]> stepImage(@PathVariable String routineId, @PathVariable String stepId) {
    AdminRoutineStepImage image = adminRoutineService.getStepImage(routineId, stepId);
    return ResponseEntity.ok()
      .contentType(MediaType.parseMediaType(image.contentType()))
      .body(image.bytes());
  }
}
