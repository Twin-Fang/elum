package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminRoutineService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@Controller
@RequiredArgsConstructor
public class AdminRoutineController {

  private final AdminRoutineService adminRoutineService;

  @GetMapping("/admin/routines")
  public String list(Model model) {
    model.addAttribute("routines", adminRoutineService.getAll());
    return "admin/routines";
  }

  @GetMapping("/admin/routines/{id}")
  public String detail(@PathVariable String id, Model model) {
    model.addAttribute("routine", adminRoutineService.getDetail(id));
    return "admin/routine-detail";
  }
}
