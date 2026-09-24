package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustForm;
import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustType;
import com.chuseok22.elumserver.admin.application.dto.request.CreditPolicyForm;
import com.chuseok22.elumserver.admin.application.dto.response.CreditAdjustPreview;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService.JobFilter;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService.MemberFilter;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService.MemberSort;
import com.chuseok22.elumserver.admin.application.service.AdminCreditService;
import com.chuseok22.elumserver.admin.application.service.AdminCreditService.PublishResult;
import com.chuseok22.elumserver.credit.application.service.PolicyDraft;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import java.security.Principal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import org.springframework.web.util.UriComponentsBuilder;

/**
 * 관리자 AI 크레딧 화면 (#407) — 개요 · 회원별 · 회원 상세(조정·수동 반환) · 정책 · 작업 탐색.
 *
 * <p>쓰기(조정·정책)는 두 단계다. 미리보기 POST 가 같은 화면에 "남음 12 → 42, 즉시 적용" 같은 확인을 그리고,
 * 확인 버튼이 같은 값을 다시 보내 반영한다. 입력 오류는 폼 오류(flash·화면 경고)로 보이고 500 이 되지 않는다.
 *
 * <p>필터 값은 문자열로 받아 직접 해석한다 — enum·날짜를 바로 받으면 틀린 값 하나에 400 영문 화면이 뜬다.
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminCreditController {

  private final AdminCreditQueryService queryService;
  private final AdminCreditService creditService;

  // --- 개요 ---

  @GetMapping("/admin/credits")
  public String overview(@RequestParam(name = "week", required = false) String week, Model model) {
    model.addAttribute("overview", queryService.overview(week));
    return "admin/credits";
  }

  // --- 회원별 ---

  @GetMapping("/admin/credits/members")
  public String members(
    @RequestParam(name = "week", required = false) String week,
    @RequestParam(name = "keyword", required = false) String keyword,
    @RequestParam(name = "sort", required = false) String sort,
    @RequestParam(name = "exhausted", defaultValue = "false") boolean exhausted,
    @RequestParam(name = "overage", defaultValue = "false") boolean overage,
    @RequestParam(name = "frozen", defaultValue = "false") boolean frozen,
    @RequestParam(name = "page", defaultValue = "0") int page,
    Model model
  ) {
    MemberSort memberSort = MemberSort.of(sort);
    MemberFilter filter = new MemberFilter(keyword, exhausted, overage, frozen);
    model.addAttribute("period", queryService.periodOf(week));
    model.addAttribute("rows", queryService.members(week, filter, memberSort, page));
    model.addAttribute("filter", filter);
    model.addAttribute("keyword", keyword == null ? "" : keyword);
    model.addAttribute("sort", memberSort.name());
    return "admin/credits-members";
  }

  // --- 회원 상세 ---

  @GetMapping("/admin/credits/members/{memberId}")
  public String memberDetail(
    @PathVariable String memberId,
    @RequestParam(name = "jobPage", defaultValue = "0") int jobPage,
    @RequestParam(name = "ledgerType", required = false) String ledgerType,
    @RequestParam(name = "ledgerPage", defaultValue = "0") int ledgerPage,
    Model model
  ) {
    fillMemberDetail(model, memberId, jobPage, ledgerType, ledgerPage);
    model.addAttribute("form", new CreditAdjustForm("GRANT", "", CreditAdjustForm.EXPIRY_WEEK_END, "", ""));
    return "admin/credits-member-detail";
  }

  /// 조정 미리보기 — 같은 화면에 확인 상자를 그린다. 아무것도 쓰지 않는다.
  @PostMapping("/admin/credits/members/{memberId}/adjust/preview")
  public String previewAdjust(@PathVariable String memberId, @ModelAttribute CreditAdjustForm form, Model model) {
    fillMemberDetail(model, memberId, 0, null, 0);
    model.addAttribute("form", form);
    try {
      AdminCreditService.requireReason(form.reason());
      CreditAdjustType type = form.parsedType();
      LocalDateTime expiresAt = type == CreditAdjustType.GRANT
        ? creditService.resolveExpiry(form.expiryModeOrDefault(), form.expiryDate()) : null;
      CreditAdjustPreview preview = creditService.previewAdjust(memberId, type, form.parsedAmount(), expiresAt);
      model.addAttribute("preview", preview);
    } catch (IllegalArgumentException e) {
      model.addAttribute("errorMessage", "조정할 수 없어요: " + e.getMessage() + " (E-CRD-001)");
    }
    return "admin/credits-member-detail";
  }

  @PostMapping("/admin/credits/members/{memberId}/adjust")
  public String adjust(
    @PathVariable String memberId, @ModelAttribute CreditAdjustForm form, Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    try {
      CreditAdjustType type = form.parsedType();
      LocalDateTime expiresAt = type == CreditAdjustType.GRANT
        ? creditService.resolveExpiry(form.expiryModeOrDefault(), form.expiryDate()) : null;
      CreditAdjustPreview applied = creditService.adjust(
        memberId, type, form.parsedAmount(), expiresAt, actorOf(principal), form.reason());
      redirectAttributes.addFlashAttribute("message",
        type.getLabel() + " 반영했어요. " + applied.summary().replace(", 즉시 적용", ""));
    } catch (IllegalArgumentException e) {
      redirectAttributes.addFlashAttribute("errorMessage", "조정하지 못했어요: " + e.getMessage() + " (E-CRD-001)");
    }
    return "redirect:/admin/credits/members/" + memberId;
  }

  /**
   * 멈춘 예약 수동 반환. 회원 상세·작업 탐색 두 곳에서 부른다 — back 이 있으면 그 화면으로 돌아간다.
   */
  @PostMapping("/admin/credits/jobs/{jobId}/release")
  public String release(
    @PathVariable String jobId,
    @RequestParam(name = "reason", required = false) String reason,
    @RequestParam(name = "back", required = false) String back,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    try {
      creditService.manualRelease(jobId, actorOf(principal), reason);
      redirectAttributes.addFlashAttribute("message", "예약을 반환했어요. 잔액이 바로 돌아가요.");
    } catch (IllegalArgumentException e) {
      redirectAttributes.addFlashAttribute("errorMessage", "반환하지 못했어요: " + e.getMessage() + " (E-CRD-002)");
    }
    return "redirect:" + safeBack(back);
  }

  // --- 정책 ---

  @GetMapping("/admin/credits/policy")
  public String policy(Model model) {
    fillPolicy(model);
    model.addAttribute("form", model.getAttribute("currentValues"));
    return "admin/credits-policy";
  }

  @PostMapping("/admin/credits/policy/preview")
  public String previewPolicy(@ModelAttribute CreditPolicyForm form, Model model) {
    fillPolicy(model);
    model.addAttribute("form", form);
    try {
      PolicyDraft draft = form.toDraft();
      model.addAttribute("preview", creditService.previewPolicy(draft));
    } catch (IllegalArgumentException e) {
      model.addAttribute("errorMessage", "미리볼 수 없어요: " + e.getMessage() + " (E-CRD-003)");
    }
    return "admin/credits-policy";
  }

  @PostMapping("/admin/credits/policy")
  public String publishPolicy(
    @ModelAttribute CreditPolicyForm form, Principal principal, RedirectAttributes redirectAttributes
  ) {
    try {
      PublishResult result = creditService.publishPolicy(form.toDraft(), actorOf(principal));
      String applied = AiCreditPolicy.GRANT_APPLY_IMMEDIATE.equals(result.policy().getGrantApply())
        ? " 이번 주 지급을 " + result.adjustedAccounts() + "개 계정에 바로 맞췄어요. 이번 주에 처음 받는 회원도 새 지급량이에요."
        : " 새 지급량은 다음 주부터 적용돼요. 이번 주는 이번 주에 처음 받는 회원도 이전 지급량이에요.";
      redirectAttributes.addFlashAttribute("message",
        "정책 v" + result.policy().getVersion() + " 발행했어요." + applied);
    } catch (IllegalArgumentException e) {
      redirectAttributes.addFlashAttribute("errorMessage", "발행하지 못했어요: " + e.getMessage() + " (E-CRD-003)");
    }
    return "redirect:/admin/credits/policy";
  }

  // --- 작업 탐색 ---

  @GetMapping("/admin/credits/jobs")
  public String jobs(
    @RequestParam(name = "status", required = false) String status,
    @RequestParam(name = "kind", required = false) String kind,
    @RequestParam(name = "from", required = false) String from,
    @RequestParam(name = "to", required = false) String to,
    @RequestParam(name = "overage", defaultValue = "false") boolean overage,
    @RequestParam(name = "mismatch", defaultValue = "false") boolean mismatch,
    @RequestParam(name = "q", required = false) String q,
    @RequestParam(name = "page", defaultValue = "0") int page,
    Model model
  ) {
    JobFilter filter = new JobFilter(enumOf(CreditJobStatus.class, status), enumOf(CreditJobKind.class, kind),
      dateOf(from), dateOf(to), overage, mismatch, q);
    model.addAttribute("rows", queryService.jobs(filter, page));
    model.addAttribute("filter", filter);
    model.addAttribute("statuses", CreditJobStatus.values());
    model.addAttribute("kinds", CreditJobKind.values());
    model.addAttribute("q", q == null ? "" : q);
    return "admin/credits-jobs";
  }

  // --- 공통 ---

  private void fillMemberDetail(Model model, String memberId, int jobPage, String ledgerType, int ledgerPage) {
    model.addAttribute("detail",
      queryService.memberDetail(memberId, jobPage, enumOf(CreditLedgerType.class, ledgerType), ledgerPage));
    model.addAttribute("ledgerTypes", CreditLedgerType.values());
    model.addAttribute("adjustTypes", CreditAdjustType.values());
  }

  private void fillPolicy(Model model) {
    AiCreditPolicy current = creditService.currentPolicy();
    model.addAttribute("current", current);
    // 지급량·단가는 JSON 이라 화면에서 꺼내기 번거롭다. 폼과 같은 모양으로 풀어 둔다.
    model.addAttribute("currentValues", CreditPolicyForm.of(current));
    model.addAttribute("history", creditService.policyHistory());
  }

  /// 틀린 값은 필터를 끈 것으로 본다(400 대신).
  private static <E extends Enum<E>> E enumOf(Class<E> type, String raw) {
    if (raw == null || raw.isBlank()) {
      return null;
    }
    try {
      return Enum.valueOf(type, raw.trim());
    } catch (IllegalArgumentException e) {
      return null;
    }
  }

  private static LocalDate dateOf(String raw) {
    if (raw == null || raw.isBlank()) {
      return null;
    }
    try {
      return LocalDate.parse(raw.trim());
    } catch (DateTimeParseException e) {
      return null;
    }
  }

  /// 돌아갈 곳은 관리자 크레딧 화면 안으로만 — 폼 값으로 바깥 주소로 튕기지 않게.
  static String safeBack(String back) {
    if (back == null || !back.startsWith("/admin/credits") || back.contains("//") || back.contains("\\")
      || back.contains("\r") || back.contains("\n")) {
      return "/admin/credits/jobs";
    }
    return UriComponentsBuilder.fromUriString(back).build().toUriString();
  }

  /// 원장 actor — 로그인한 관리자 아이디. 세션이 없으면(테스트 등) 서비스가 admin 으로 적는다.
  private static String actorOf(Principal principal) {
    return principal == null ? null : principal.getName();
  }
}
