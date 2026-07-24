package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigView;
import com.chuseok22.elumserver.systemconfig.core.ConfigGroup;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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
public class AdminConfigController {

  private final SystemConfigService systemConfigService;

  @GetMapping("/admin/settings")
  public String settings(Model model) {
    // ConfigGroup 선언 순서대로 그룹 카드를 고정 표시한다.
    Map<ConfigGroup, List<SystemConfigView>> grouped = new LinkedHashMap<>();
    List<SystemConfigView> views = systemConfigService.getAllViews();
    for (ConfigGroup group : ConfigGroup.values()) {
      grouped.put(group, views.stream().filter(view -> view.group() == group).toList());
    }
    model.addAttribute("groups", grouped);
    return "admin/settings";
  }

  @PostMapping("/admin/settings/{key}")
  public String update(
    @PathVariable ConfigKey key,
    @RequestParam("value") String value,
    RedirectAttributes redirectAttributes
  ) {
    try {
      systemConfigService.update(key, value);
      redirectAttributes.addFlashAttribute("message", key.getLabel() + " 설정을 저장했습니다.");
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute(
        "errorMessage", key.getLabel() + " 저장 실패: 값이 올바르지 않습니다. (E-CFG-001)"
      );
    }
    return "redirect:/admin/settings";
  }

  @PostMapping("/admin/settings/{key}/reset")
  public String reset(@PathVariable ConfigKey key, RedirectAttributes redirectAttributes) {
    systemConfigService.resetToDefault(key);
    redirectAttributes.addFlashAttribute("message", key.getLabel() + " 설정을 기본값으로 복원했습니다.");
    return "redirect:/admin/settings";
  }
}
