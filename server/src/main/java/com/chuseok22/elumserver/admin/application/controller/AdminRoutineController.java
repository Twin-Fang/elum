package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStepImage;
import com.chuseok22.elumserver.admin.application.service.AdminRoutineService;
import lombok.RequiredArgsConstructor;
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

  @GetMapping("/admin/routines")
  public String list(
    @RequestParam(name = "keyword", required = false) String keyword,
    @RequestParam(name = "page", defaultValue = "0") int page,
    Model model
  ) {
    model.addAttribute("routines", adminRoutineService.search(keyword, page));
    model.addAttribute("keyword", keyword);
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
