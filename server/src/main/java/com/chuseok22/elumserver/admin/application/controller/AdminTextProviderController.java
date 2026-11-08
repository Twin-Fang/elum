package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminTextProviderService;
import com.chuseok22.elumserver.admin.application.service.SettingsSection;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import java.security.Principal;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 관리자 텍스트 제공자 폼 (#1083): 제공자 시도 순서(추가·빼기·올리기·내리기), Claude 키(추가·삭제·순서·켜고 끄기·교체·별명)
 * 모두 폼 제출 > 설정 화면으로 되돌아감, 실패 사유는 상단 알림 (E-CFG 코드 포함)
 */
@Controller
@RequiredArgsConstructor
public class AdminTextProviderController {

  // 제공자 순서·Claude 키 카드는 AI 설정 화면에 있음
  private static final String SETTINGS_REDIRECT = "redirect:" + SettingsSection.AI.getPath();
  // direction 요청값: 올리기
  private static final String DIRECTION_UP = "up";

  private final AdminTextProviderService adminTextProviderService;

  @PostMapping("/admin/settings/text-chain/add")
  public String addToChain(@RequestParam("provider") TextProvider provider, Principal principal,
    RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, provider.getLabel() + " 을(를) 제공자 순서에 넣었어요.",
      () -> adminTextProviderService.addToChain(provider, actorOf(principal)));
  }

  @PostMapping("/admin/settings/text-chain/remove")
  public String removeFromChain(@RequestParam("provider") TextProvider provider, Principal principal,
    RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, provider.getLabel() + " 을(를) 제공자 순서에서 뺐어요.",
      () -> adminTextProviderService.removeFromChain(provider, actorOf(principal)));
  }

  @PostMapping("/admin/settings/text-chain/move")
  public String moveInChain(@RequestParam("provider") TextProvider provider,
    @RequestParam("direction") String direction, Principal principal, RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, "제공자 순서를 바꿨어요.",
      () -> adminTextProviderService.moveInChain(provider, DIRECTION_UP.equals(direction), actorOf(principal)));
  }

  @PostMapping("/admin/settings/claude-keys/add")
  public String addClaudeKey(@RequestParam("nickname") String nickname, @RequestParam("apiKey") String apiKey,
    Principal principal, RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, "Claude 키를 추가했어요.",
      () -> adminTextProviderService.addClaudeKey(nickname, apiKey, actorOf(principal)));
  }

  @PostMapping("/admin/settings/claude-keys/{keyId}/delete")
  public String removeClaudeKey(@PathVariable String keyId, Principal principal,
    RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, "Claude 키를 지웠어요.",
      () -> adminTextProviderService.removeClaudeKey(keyId, actorOf(principal)));
  }

  @PostMapping("/admin/settings/claude-keys/{keyId}/move")
  public String moveClaudeKey(@PathVariable String keyId, @RequestParam("direction") String direction,
    Principal principal, RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, "Claude 키 순서를 바꿨어요.",
      () -> adminTextProviderService.moveClaudeKey(keyId, DIRECTION_UP.equals(direction), actorOf(principal)));
  }

  @PostMapping("/admin/settings/claude-keys/{keyId}/enabled")
  public String setClaudeKeyEnabled(@PathVariable String keyId, @RequestParam("enabled") boolean isEnabled,
    Principal principal, RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, isEnabled ? "Claude 키를 켰어요." : "Claude 키를 껐어요.",
      () -> adminTextProviderService.setClaudeKeyEnabled(keyId, isEnabled, actorOf(principal)));
  }

  @PostMapping("/admin/settings/claude-keys/{keyId}/replace")
  public String replaceClaudeKey(@PathVariable String keyId, @RequestParam("apiKey") String apiKey,
    Principal principal, RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, "Claude 키 값을 바꿨어요.",
      () -> adminTextProviderService.replaceClaudeKey(keyId, apiKey, actorOf(principal)));
  }

  @PostMapping("/admin/settings/claude-keys/{keyId}/rename")
  public String renameClaudeKey(@PathVariable String keyId, @RequestParam("nickname") String nickname,
    Principal principal, RedirectAttributes redirectAttributes) {
    return run(redirectAttributes, "Claude 키 별명을 바꿨어요.",
      () -> adminTextProviderService.renameClaudeKey(keyId, nickname, actorOf(principal)));
  }

  /// 실행 > 성공 문구 또는 실패 사유를 알림으로 (설정 화면과 같은 E-CFG 코드)
  private String run(RedirectAttributes redirectAttributes, String successMessage, Runnable action) {
    try {
      action.run();
      redirectAttributes.addFlashAttribute("message", successMessage);
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute("errorMessage", "저장 실패: " + failureReason(e));
    }
    return SETTINGS_REDIRECT;
  }

  private static String failureReason(CustomException e) {
    return switch (e.getErrorCode()) {
      case SECRET_MASTER_KEY_MISSING -> "서버에 암호화 키가 없어 비밀값을 저장할 수 없습니다. (E-CFG-002)";
      case TEXT_PROVIDER_UNAVAILABLE -> "그 제공자의 API 키가 없습니다. 키를 먼저 저장하세요. (E-CFG-003)";
      default -> (e.getDetail() == null || e.getDetail().isBlank() ? "값이 올바르지 않습니다." : e.getDetail())
        + " (E-CFG-001)";
    };
  }

  private static String actorOf(Principal principal) {
    return principal == null ? null : principal.getName();
  }
}
