package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.PromptUpdateRequest;
import com.chuseok22.elumserver.admin.application.service.AdminPromptService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
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

  @GetMapping("/admin/prompts/{key}/history")
  public String history(@PathVariable PromptKey key, Model model) {
    model.addAttribute("prompt", adminPromptService.getTemplate(key));
    model.addAttribute("histories", adminPromptService.getHistory(key));
    return "admin/prompt-history";
  }

  @PostMapping("/admin/prompts/{key}")
  public String update(
    @PathVariable PromptKey key,
    @Valid @ModelAttribute PromptUpdateRequest request,
    BindingResult bindingResult,
    RedirectAttributes redirectAttributes
  ) {
    // 요청 DTO에 검증 어노테이션이 없어 bindingResult 는 공백을 잡지 못한다. 실제 검사는
    // 서비스가 하고, 여기서는 거절을 화면에 알린다. 전에는 공백이 "저장했습니다"로 통과했다.
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("errorMessage", "프롬프트 내용을 입력해주세요. (E-PRM-001)");
      return "redirect:/admin/prompts";
    }
    try {
      adminPromptService.update(key, request.content());
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute("errorMessage",
        key.getLabel() + " 프롬프트를 저장하지 않았습니다. 내용을 입력해주세요. (E-PRM-001)");
      return "redirect:/admin/prompts";
    }
    redirectAttributes.addFlashAttribute("message", key.getLabel() + " 프롬프트를 저장했습니다.");
    return "redirect:/admin/prompts";
  }
}
