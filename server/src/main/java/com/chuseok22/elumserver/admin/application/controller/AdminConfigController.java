package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.AdminImageProviderView;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTextProviderView;
import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import com.chuseok22.elumserver.admin.application.service.SystemConfigOverviewService;
import com.chuseok22.elumserver.admin.application.service.PromptLocaleGate;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.dto.response.MemberPickerItem;
import com.chuseok22.elumserver.member.application.service.MemberPickerService;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigValueValidator;
import com.chuseok22.elumserver.systemconfig.core.ConfigGroup;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.security.Principal;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
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

  // 없는 회원 ID 거부 사유에 보일 ID 앞부분 길이
  private static final int MEMBER_ID_PREVIEW_LENGTH = 8;

  private final SystemConfigService systemConfigService;
  private final ImageClientRouter imageClientRouter;
  private final TextClientRouter textClientRouter;
  private final PromptLocaleGate promptLocaleGate;
  private final SystemConfigOverviewService overviewService;
  private final MemberPickerService memberPickerService;

  @GetMapping("/admin/settings")
  public String settings(Model model) {
    // 표 행(최근 변경순) + 상단 요약 + Free/Pro 비교
    List<SettingRow> rows = overviewService.buildRows();
    model.addAttribute("rows", rows);
    LocalDateTime now = LocalDateTime.now();
    model.addAttribute("overview", overviewService.buildOverview(rows, now));
    // "오늘 변경" 칩 기준일
    model.addAttribute("today", now.toLocalDate());
    // 필터 칩: 그룹 이름 > 표시 이름 (선언 순서)
    Map<String, String> groupLabelByName = new LinkedHashMap<>();
    rows.stream().sorted(java.util.Comparator.comparing(row -> ConfigGroup.valueOf(row.groupName()).ordinal()))
      .forEach(row -> groupLabelByName.putIfAbsent(row.groupName(), row.groupLabel()));
    model.addAttribute("groupLabelByName", groupLabelByName);
    // "규칙에 어긋난 값" 칩: 저장 뒤 규칙이 바뀌어 지금 규칙에 맞지 않는 저장값 수
    model.addAttribute("ruleWarningCount", rows.stream().filter(SettingRow::hasValidationWarning).count());
    model.addAttribute("imageProviders", imageProviderViews());
    model.addAttribute("textProviders", textProviderViews());
    return "admin/settings";
  }

  /**
   * 리로드 없이 저장한다.
   *
   * <p>설정이 서른 개가 넘어 화면이 길다. 하나 고칠 때마다 페이지가 다시 그려지면
   * <b>스크롤이 맨 위로 튀어</b> 고치던 자리를 다시 찾아 내려가야 한다.
   *
   * <p>같은 경로를 쓰되 {@code X-Requested-With: fetch} 가 붙었을 때만 JSON을 준다.
   * 스크립트가 막힌 환경에서는 평범한 폼 제출로 떨어져 기존 폼 제출대로 동작한다 —
   * 저장 자체가 안 되는 것보다 낫다.
   */
  @PostMapping(value = "/admin/settings/{key}", headers = "X-Requested-With=fetch")
  @ResponseBody
  public Map<String, Object> updateAsync(
    @PathVariable ConfigKey key,
    @RequestParam("value") String value,
    @RequestParam(value = "reason", required = false) String reason,
    Principal principal
  ) {
    try {
      rejectValueNotReady(key, value);
      systemConfigService.update(key, value, actorOf(principal), reason);
      return Map.of("ok", true, "message", key.getLabel() + " 설정을 저장했습니다.");
    } catch (CustomException e) {
      // reason: 입력칸 옆에 그대로 보일 이유 (입력값은 화면에 그대로 둠)
      String failureReason = failureReason(e);
      return Map.of("ok", false, "message", key.getLabel() + " 저장 실패: " + failureReason, "reason", failureReason);
    }
  }

  @PostMapping("/admin/settings/{key}")
  public String update(
    @PathVariable ConfigKey key,
    @RequestParam("value") String value,
    @RequestParam(value = "reason", required = false) String reason,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    try {
      // 키 없는 제공자로 바꾸면 그 순간부터 카드 생성이 전부 실패한다. 화면 버튼이
      // 먼저 막지만, 요청을 직접 보내면 뚫리므로 여기서 한 번 더 막는다.
      rejectValueNotReady(key, value);
      systemConfigService.update(key, value, actorOf(principal), reason);
      redirectAttributes.addFlashAttribute("message", key.getLabel() + " 설정을 저장했습니다.");
    } catch (CustomException e) {
      redirectAttributes.addFlashAttribute("errorMessage", key.getLabel() + " 저장 실패: " + failureReason(e));
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
        "서버에 암호화 키가 없어 비밀값을 저장할 수 없습니다. (E-CFG-002)";
      case IMAGE_PROVIDER_UNAVAILABLE, TEXT_PROVIDER_UNAVAILABLE ->
        "그 제공자의 API 키가 없습니다. 키를 먼저 저장하세요. (E-CFG-003)";
      case CONTENT_LOCALE_NOT_READY ->
        "그 언어의 서버 문구 파일(폴백 질문·추천)이 비어 있어 켤 수 없습니다. (E-CFG-004)";
      case CONTENT_LOCALE_PROMPT_MISSING ->
        "프롬프트 행이 모두 있는 언어만 켤 수 있어요. 프롬프트 화면에서 그 언어의 '기본값으로 행 만들기'를 누르고 시험한 뒤 다시 켜세요. (E-CFG-005)";
      // 값 검사 거부: 검사기가 준 이유 (없으면 일반 문구)
      default -> (e.getDetail() == null || e.getDetail().isBlank() ? "값이 올바르지 않습니다." : e.getDetail())
        + " (E-CFG-001)";
    };
  }

  /// 값 형식과 별개로 지금 상태 때문에 못 받는 값 거부: 키 없는 제공자, 준비 안 된 언어, 없는 회원
  private void rejectValueNotReady(ConfigKey key, String value) {
    switch (key) {
      case IMAGE_PROVIDER_SELECTED -> rejectUnavailableImageProvider(value);
      case TEXT_PROVIDER_SELECTED -> rejectUnavailableTextProvider(value);
      case ENABLED_CONTENT_LOCALES -> rejectIncompleteLocales(value);
      case ADS_ALWAYS_SHOWN_MEMBER_IDS -> rejectUnknownMembers(value);
      default -> {
        // 그 외 설정은 상태에 따라 막을 것이 없다.
      }
    }
  }

  /**
   * 없는 회원 ID 는 저장하지 않는다 (오타가 저장되면 광고 시험이 조용히 빗나감)
   * 형식이 틀린 항목은 여기서 건너뛰고 서비스의 형식 검사가 거부
   */
  private void rejectUnknownMembers(String value) {
    List<String> memberIds = SystemConfigValueValidator.splitListItems(value).stream()
      .filter(SystemConfigValueValidator::isMemberIdFormat)
      .toList();
    if (memberIds.isEmpty()) {
      return;
    }
    Set<String> existingIds = memberPickerService.findExisting(memberIds).stream()
      .map(MemberPickerItem::id)
      .collect(Collectors.toSet());
    List<String> unknownIdPreviews = memberIds.stream()
      .filter(memberId -> !existingIds.contains(memberId))
      .map(memberId -> memberId.substring(0, MEMBER_ID_PREVIEW_LENGTH) + "…")
      .toList();
    if (!unknownIdPreviews.isEmpty()) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE,
        "없는 회원 ID가 있어요: " + String.join(", ", unknownIdPreviews));
    }
  }

  /**
   * 프롬프트 행이 모자라거나 서버 문구 파일(폴백 질문·추천)이 비어 있는 언어는 켤 수 없다.
   * 켜 두면 다음 기동의 시작 검사(RoutinePhrasesStartupGuard)가 서버를 세우지 않으므로 화면에서 먼저 막는다.
   * 모르는 코드는 normalize 가 SYSTEM_CONFIG_INVALID_VALUE 로 거절한다.
   */
  private void rejectIncompleteLocales(String value) {
    Set<AppLocale> requested = EnabledLocales.parse(EnabledLocales.normalize(value));
    // 프롬프트 행 먼저 (관리자 화면에서 고칠 수 있는 쪽), 서버 문구 파일은 배포로 고침
    promptLocaleGate.requireReady(requested);
    if (!RoutinePhrases.standard().incompleteLocales(requested).isEmpty()) {
      throw new CustomException(ErrorCode.CONTENT_LOCALE_NOT_READY);
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
  public String reset(
    @PathVariable ConfigKey key,
    @RequestParam(value = "reason", required = false) String reason,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    systemConfigService.resetToDefault(key, actorOf(principal), reason);
    redirectAttributes.addFlashAttribute("message", key.getLabel() + " 설정을 기본값으로 복원했습니다.");
    return "redirect:/admin/settings";
  }

  /// 이력의 변경자 — 로그인한 관리자 아이디. 세션이 없으면(테스트 등) 서비스가 system 으로 적는다.
  private static String actorOf(Principal principal) {
    return principal == null ? null : principal.getName();
  }
}
