package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminMemberService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@Controller
@RequiredArgsConstructor
public class AdminMemberController {

  private final AdminMemberService adminMemberService;

  @GetMapping("/admin/members")
  public String list(Model model) {
    model.addAttribute("members", adminMemberService.getAll());
    return "admin/members";
  }

  @GetMapping("/admin/members/{id}")
  public String detail(@PathVariable String id, Model model) {
    model.addAttribute("member", adminMemberService.getDetail(id));
    return "admin/member-detail";
  }
}
