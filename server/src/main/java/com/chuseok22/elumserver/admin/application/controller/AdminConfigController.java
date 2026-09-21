package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.AdminImageProviderView;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTextProviderView;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
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
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
@RequiredArgsConstructor
public class AdminConfigController {

  private final SystemConfigService systemConfigService;
  private final ImageClientRouter imageClientRouter;
  private final TextClientRouter textClientRouter;

  @GetMapping("/admin/settings")
  public String settings(Model model) {
    // ConfigGroup 선언 순서대로 그룹 카드를 고정 표시한다.
    Map<ConfigGroup, List<SystemConfigView>> grouped = new LinkedHashMap<>();
    List<SystemConfigView> views = systemConfigService.getAllViews();
    for (ConfigGroup group : ConfigGroup.values()) {
      grouped.put(group, views.stream().filter(view -> view.group() == group).toList());
    }
    model.addAttribute("groups", grouped);
    model.addAttribute("imageProviders", imageProviderViews());
    model.addAttribute("textProviders", textProviderViews());
    return "admin/settings";
  }

  /**
   * 리로드 없이 저장한다 (이슈 #248).
   *
   * <p>설정이 서른 개가 넘어 화면이 길다. 하나 고칠 때마다 페이지가 다시 그려지면
   * <b>스크롤이 맨 위로 튀어</b> 고치던 자리를 다시 찾아 내려가야 한다.
   *
   * <p>같은 경로를 쓰되 {@code X-Requested-With: fetch} 가 붙었을 때만 JSON을 준다.
   * 스크립트가 막힌 환경에서는 평범한 폼 제출로 떨어져 예전처럼 동작한다 —
   * 저장 자체가 안 되는 것보다 낫다.
   */
  @PostMapping(value = "/admin/settings/{key}", headers = "X-Requested-With=fetch")
  @ResponseBody
  public Map<String, Object> updateAsync(
    @PathVariable ConfigKey key,
    @RequestParam("value") String value
  ) {
    try {
      rejectUnavailableProvider(key, value);
      systemConfigService.update(key, value);
      return Map.of("ok", true, "message", key.getLabel() + " 설정을 저장했습니다.");
    } catch (CustomException e) {
      return Map.of("ok", false, "message", key.getLabel() + failureReason(e));
    }
  }

  @PostMapping("/admin/settings/{key}")
  public String update(
    @PathVariable ConfigKey key,
    @RequestParam("value") String value,
    RedirectAttributes redirectAttributes
  ) {
    try {
      // 키 없는 제공자로 바꾸면 그 순간부터 카드 생성이 전부 실패한다. 화면 버튼이
      // 먼저 막지만, 요청을 직접 보내면 뚫리므로 여기서 한 번 더 막는다.
      rejectUnavailableProvider(key, value);
      systemConfigService.update(key, value);
      redirectAttributes.addFlashAttribute("message", key.getLabel() + " 설정을 저장했습니다.");
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute("errorMessage", key.getLabel() + failureReason(e));
    }
    return "redirect:/admin/settings";
  }

  /**
   * 저장 실패 사유. 비밀값은 실패 이유가 다르다 — "값이 이상하다"로 뭉뚱그리면
   * 관리자가 서버 설정 문제를 값 문제로 오해해 계속 다시 입력하게 된다.
   */
  private String failureReason(CustomException e) {
    return switch (e.getErrorCode()) {
      case SECRET_MASTER_KEY_MISSING ->
        " 저장 실패: 서버에 암호화 키가 없어 비밀값을 저장할 수 없습니다. (E-CFG-002)";
      case IMAGE_PROVIDER_UNAVAILABLE, TEXT_PROVIDER_UNAVAILABLE ->
        " 저장 실패: 그 제공자의 API 키가 없습니다. 키를 먼저 저장하세요. (E-CFG-003)";
      default -> " 저장 실패: 값이 올바르지 않습니다. (E-CFG-001)";
    };
  }

  private void rejectUnavailableProvider(ConfigKey key, String value) {
    switch (key) {
      case IMAGE_PROVIDER_SELECTED -> rejectUnavailableImageProvider(value);
      case TEXT_PROVIDER_SELECTED -> rejectUnavailableTextProvider(value);
      default -> {
        // 제공자 선택이 아닌 설정은 검사할 것이 없다.
      }
    }
  }

  private void rejectUnavailableImageProvider(String value) {
    ImageProvider provider;
    try {
      provider = ImageProvider.valueOf(value.trim());
    } catch (IllegalArgumentException e) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    boolean usable = imageClientRouter.of(provider)
      .map(client -> client.available())
      .orElse(false);
    if (!usable) {
      throw new CustomException(ErrorCode.IMAGE_PROVIDER_UNAVAILABLE);
    }
  }

  private void rejectUnavailableTextProvider(String value) {
    TextProvider provider;
    try {
      provider = TextProvider.valueOf(value.trim());
    } catch (IllegalArgumentException e) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    boolean usable = textClientRouter.of(provider)
      .map(client -> client.available())
      .orElse(false);
    if (!usable) {
      throw new CustomException(ErrorCode.TEXT_PROVIDER_UNAVAILABLE);
    }
  }

  // 단가가 둘이라 이미지처럼 한 값으로 정렬할 수 없다. 선언 순서를 그대로 보여준다.
  private List<AdminTextProviderView> textProviderViews() {
    TextProvider current = textClientRouter.selected();
    return textClientRouter.all().stream()
      .map(client -> AdminTextProviderView.of(
        client, current,
        systemConfigService.getDouble(client.provider().getInputPriceKey()),
        systemConfigService.getDouble(client.provider().getOutputPriceKey())
      ))
      .sorted(java.util.Comparator.comparing(AdminTextProviderView::name))
      .toList();
  }

  private List<AdminImageProviderView> imageProviderViews() {
    ImageProvider current = imageClientRouter.selected();
    return imageClientRouter.all().stream()
      .map(client -> AdminImageProviderView.of(
        client, current, systemConfigService.getDouble(client.provider().getPriceKey())))
      .sorted(java.util.Comparator.comparingDouble(AdminImageProviderView::pricePerImage))
      .toList();
  }

  @PostMapping("/admin/settings/{key}/reset")
  public String reset(@PathVariable ConfigKey key, RedirectAttributes redirectAttributes) {
    systemConfigService.resetToDefault(key);
    redirectAttributes.addFlashAttribute("message", key.getLabel() + " 설정을 기본값으로 복원했습니다.");
    return "redirect:/admin/settings";
  }
}
