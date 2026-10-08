package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/// 보호자가 보낸 의견을 관리자 화면에서 보고 지운다. 자동 삭제는 없다.
@Controller
@RequiredArgsConstructor
public class AdminFeedbackController {

  private final FeedbackService feedbackService;

  @GetMapping("/admin/feedback")
  public String list(@RequestParam(name = "page", defaultValue = "0") int page, Model model) {
    model.addAttribute("feedbacks", feedbackService.list(page));
    return "admin/feedback";
  }

  @GetMapping("/admin/feedback/{id}")
  public String detail(@PathVariable("id") String id, Model model) {
    model.addAttribute("feedback", feedbackService.get(id));
    return "admin/feedback-detail";
  }

  @PostMapping("/admin/feedback/{id}/delete")
  public String delete(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    feedbackService.delete(id);
    redirectAttributes.addFlashAttribute("message", "의견을 지웠어요.");
    return "redirect:/admin/feedback";
  }
}
