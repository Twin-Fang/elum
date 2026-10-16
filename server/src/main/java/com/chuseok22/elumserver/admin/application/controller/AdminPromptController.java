package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.PromptUpdateRequest;
import com.chuseok22.elumserver.admin.application.dto.response.PromptLocaleView;
import com.chuseok22.elumserver.admin.application.service.AdminPromptService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateSeeder;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import jakarta.validation.Valid;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminPromptController {

  private final AdminPromptService adminPromptService;
  private final EnabledLocales enabledLocales;

  @GetMapping("/admin/prompts")
  public String list(@RequestParam(value = "locale", defaultValue = "ko") String locale, Model model) {
    AppLocale selected = parseLocale(locale);
    model.addAttribute("prompts", adminPromptService.getAll(selected));
    addLocaleModel(model, selected);
    return "admin/prompts";
  }

  @GetMapping("/admin/prompts/{key}/history")
  public String history(
    @PathVariable PromptKey key, @RequestParam(value = "locale", defaultValue = "ko") String locale, Model model
  ) {
    AppLocale selected = parseLocale(locale);
    model.addAttribute("prompt", adminPromptService.getTemplate(key, selected));
    model.addAttribute("histories", adminPromptService.getHistory(key, selected));
    model.addAttribute("selectedLocale", selected.code());
    return "admin/prompt-history";
  }

  @PostMapping("/admin/prompts/{key}")
  public String update(
    @PathVariable PromptKey key,
    @RequestParam(value = "locale", defaultValue = "ko") String locale,
    @Valid @ModelAttribute PromptUpdateRequest request,
    BindingResult bindingResult,
    RedirectAttributes redirectAttributes
  ) {
    AppLocale target = parseLocale(locale);
    String back = "redirect:/admin/prompts?locale=" + target.code();
    // 요청 DTO에 검증 어노테이션이 없어 bindingResult 는 공백을 잡지 못한다. 실제 검사는
    // 서비스가 하고, 여기서는 거절을 화면에 알린다.
    if (bindingResult.hasErrors()) {
      redirectAttributes.addFlashAttribute("errorMessage", "프롬프트 내용을 입력해주세요. (E-PRM-001)");
      return back;
    }
    try {
      adminPromptService.update(key, target, request.content());
    } catch (CustomException e) {
      String reason = e.getErrorCode() == ErrorCode.PROMPT_TEMPLATE_NOT_FOUND
        ? "이 언어에는 아직 없는 프롬프트예요. 위의 '기본값으로 행 만들기'를 먼저 눌러 주세요. (E-PRM-002)"
        : "내용을 입력해주세요. (E-PRM-001)";
      redirectAttributes.addFlashAttribute("errorMessage", key.getLabel() + " 프롬프트를 저장하지 않았습니다. " + reason);
      return back;
    }
    redirectAttributes.addFlashAttribute("message", key.getLabel() + " 프롬프트를 저장했습니다.");
    return back;
  }

  // 그 언어의 없는 프롬프트 행을 기본값으로 생성 (있는 행은 건드리지 않음, ko 는 기동 때 생성되므로 제외)
  @PostMapping("/admin/prompts/locales/{locale}/seed")
  public String seed(@PathVariable String locale, RedirectAttributes redirectAttributes) {
    AppLocale target = parseLocale(locale);
    String back = "redirect:/admin/prompts?locale=" + target.code();
    if (target == AppLocale.KO) {
      redirectAttributes.addFlashAttribute("message", "ko 프롬프트는 서버가 켜질 때 만들어져요.");
      return back;
    }
    PromptTemplateSeeder.SeedResult result;
    try {
      result = adminPromptService.seedLocale(target);
    } catch (RuntimeException e) {
      log.error("[admin prompt seed] failed : locale={}", target.code(), e);
      redirectAttributes.addFlashAttribute("errorMessage",
        target.code() + " 프롬프트 기본값을 만들지 못했어요. 잠시 뒤 다시 눌러 주세요. (E-PRM-003)");
      return back;
    }
    String summary = target.code() + " 프롬프트 기본값: 새로 " + result.created() + "개 만들고, 이미 있어서 건너뛴 것 "
      + result.skipped() + "개";
    if (result.failed() > 0) {
      // 동시에 두 번 눌러 겹친 경우도 여기로 옴, 다시 누르면 남은 행만 채워짐
      redirectAttributes.addFlashAttribute("errorMessage",
        summary + ", 실패 " + result.failed() + "개 (E-PRM-003) 다시 누르면 남은 행만 채워요.");
    } else {
      redirectAttributes.addFlashAttribute("message", summary);
    }
    return back;
  }

  // 모르는 코드는 ko 로 (주소를 손으로 고쳐도 화면이 깨지지 않음)
  private AppLocale parseLocale(String code) {
    if (code == null) {
      return AppLocale.KO;
    }
    try {
      return AppLocale.fromCode(code.trim());
    } catch (IllegalArgumentException e) {
      return AppLocale.KO;
    }
  }

  private void addLocaleModel(Model model, AppLocale selected) {
    Set<AppLocale> enabled = enabledLocales.current();
    List<PromptLocaleView> views = Arrays.stream(AppLocale.values())
      .map(locale -> PromptLocaleView.of(
        locale, enabled.contains(locale), adminPromptService.missingKeys(locale).size()))
      .toList();
    model.addAttribute("locales", views);
    model.addAttribute("selectedLocale", selected.code());
    model.addAttribute("localeEnabled", enabled.contains(selected));
    model.addAttribute("missingKeys", adminPromptService.missingKeys(selected));
  }
}
