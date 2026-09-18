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

  /**
   * Pro 발급. 사유를 반드시 받는다 — 나중에 "이 계정은 왜 Pro지"에 답해야 한다.
   *
   * <p>기간을 비우면 무기한이다. 심사 전이라 인앱결제를 붙일 수 없어, 지금은 이 화면이
   * Pro를 켜는 유일한 방법이다.
   */
  @PostMapping("/admin/members/{id}/grant-pro")
  public String grantPro(
    @PathVariable String id,
    @RequestParam(name = "days", required = false) Integer days,
    @RequestParam(name = "memo") String memo,
    RedirectAttributes redirectAttributes
  ) {
    adminMemberService.grantPro(id, days, memo);
    redirectAttributes.addFlashAttribute("message",
      days == null || days <= 0 ? "Pro를 무기한으로 발급했습니다." : "Pro를 " + days + "일간 발급했습니다.");
    return "redirect:/admin/members/" + id;
  }

  @PostMapping("/admin/members/{id}/revoke-pro")
  public String revokePro(@PathVariable String id, RedirectAttributes redirectAttributes) {
    adminMemberService.revokePro(id);
    redirectAttributes.addFlashAttribute("message", "Pro를 회수했습니다. 이 계정은 Free로 돌아갑니다.");
    return "redirect:/admin/members/" + id;
  }

  @PostMapping("/admin/members/{id}/force-logout")
  public String forceLogout(@PathVariable String id, RedirectAttributes redirectAttributes) {
    adminMemberService.forceLogout(id);
    redirectAttributes.addFlashAttribute("message", "강제 로그아웃했습니다. 기존 토큰이 모두 무효화됩니다.");
    return "redirect:/admin/members/" + id;
  }
}
