package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminMemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
@RequiredArgsConstructor
public class AdminMemberController {

  private final AdminMemberService adminMemberService;

  @GetMapping("/admin/members")
  public String list(
    @RequestParam(name = "keyword", required = false) String keyword,
    @RequestParam(name = "status", required = false) MemberStatus status,
    @RequestParam(name = "page", defaultValue = "0") int page,
    Model model
  ) {
    model.addAttribute("members", adminMemberService.search(keyword, status, page));
    model.addAttribute("keyword", keyword == null ? "" : keyword);
    model.addAttribute("selectedStatus", status);
    return "admin/members";
  }

  @GetMapping("/admin/members/{id}")
  public String detail(@PathVariable String id, Model model) {
    model.addAttribute("member", adminMemberService.getDetail(id));
    return "admin/member-detail";
  }

  @PostMapping("/admin/members/{id}/suspend")
  public String suspend(@PathVariable String id, RedirectAttributes redirectAttributes) {
    adminMemberService.suspend(id);
    redirectAttributes.addFlashAttribute("message", "계정을 정지했습니다. 로그인과 API 사용이 차단됩니다.");
    return "redirect:/admin/members/" + id;
  }

  @PostMapping("/admin/members/{id}/unsuspend")
  public String unsuspend(@PathVariable String id, RedirectAttributes redirectAttributes) {
    adminMemberService.unsuspend(id);
    redirectAttributes.addFlashAttribute("message", "계정 정지를 해제했습니다.");
    return "redirect:/admin/members/" + id;
  }

  @PostMapping("/admin/members/{id}/force-logout")
  public String forceLogout(@PathVariable String id, RedirectAttributes redirectAttributes) {
    adminMemberService.forceLogout(id);
    redirectAttributes.addFlashAttribute("message", "강제 로그아웃했습니다. 기존 토큰이 모두 무효화됩니다.");
    return "redirect:/admin/members/" + id;
  }
}
