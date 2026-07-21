package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.PromptUpdateRequest;
import com.chuseok22.elumserver.admin.application.service.AdminPromptService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
@RequiredArgsConstructor
public class AdminPromptController {

  private final AdminPromptService adminPromptService;

  @GetMapping("/admin/prompts")
  public String list(Model model) {
    model.addAttribute("prompts", adminPromptService.getAll());
    return "admin/prompts";
  }

  @PostMapping("/admin/prompts/{key}")
  public String update(
    @PathVariable PromptKey key,
    @Valid @ModelAttribute PromptUpdateRequest request,
    BindingResult bindingResult,
    RedirectAttributes redirectAttributes
  ) {
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("errorMessage", "프롬프트 내용을 입력해주세요.");
      return "redirect:/admin/prompts";
    }

    adminPromptService.update(key, request.content());
    redirectAttributes.addFlashAttribute("message", key.getLabel() + " 프롬프트를 저장했습니다.");
    return "redirect:/admin/prompts";
  }
}
