package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.format.AdminLogIds;
import com.chuseok22.elumserver.admin.application.service.AdminAuditService;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.member.application.service.MemberAccountKindService;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import com.chuseok22.elumserver.member.core.MemberAccountKindChange;
import java.security.Principal;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import org.springframework.web.util.UriComponentsBuilder;

/**
 * 계정 종류 바꾸기 (#1436): 회원 상세 저장, 사용 분석 분류 제안의 분류·"일반 맞음"
 * 바뀌면 관리자 기록에 전후 종류 (같은 종류면 기록 없음). 자동 분류 없음
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminAccountKindController {

  /// 잘못된 종류 값 안내 에러 코드
  static final String INVALID_KIND_ERROR_CODE = "E-ADMIN-ACCOUNT-KIND";
  private static final String ANALYTICS_PATH = "/admin/analytics";

  private final MemberAccountKindService memberAccountKindService;
  private final AdminAuditService adminAuditService;

  /// 회원 상세: 종류 저장 > 상세로
  @PostMapping("/admin/members/{id}/account-kind")
  public String saveOnMemberDetail(
    @PathVariable String id,
    @RequestParam(name = "accountKind", required = false) String accountKind,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    changeAccountKind(id, accountKind, principal, redirectAttributes);
    return "redirect:/admin/members/" + id;
  }

  /// 분류 제안: 제안 종류로 분류 > 같은 기간의 사용 분석으로
  @PostMapping("/admin/analytics/suggestions/{id}/classify")
  public String classifySuggestion(
    @PathVariable String id,
    @RequestParam(name = "accountKind", required = false) String accountKind,
    @RequestParam(name = "weeks", required = false) String weeks,
    @RequestParam(name = "includeAll", required = false) String includeAll,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    changeAccountKind(id, accountKind, principal, redirectAttributes);
    return redirectToAnalytics(weeks, includeAll);
  }

  /// 분류 제안 숨김: 이 계정은 일반 맞음 (다시 제안하지 않음)
  @PostMapping("/admin/analytics/suggestions/{id}/dismiss")
  public String dismissSuggestion(
    @PathVariable String id,
    @RequestParam(name = "weeks", required = false) String weeks,
    @RequestParam(name = "includeAll", required = false) String includeAll,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    memberAccountKindService.markReviewedAsNormal(id);
    log.info("[admin account kind] reviewed as normal : memberId={}, admin={}",
      AdminLogIds.toLoggableId(id), AdminActor.nameOf(principal));
    adminAuditService.record(AdminAuditAction.MEMBER_ACCOUNT_KIND_REVIEWED, id, MemberAccountKind.NORMAL.getLabel());
    redirectAttributes.addFlashAttribute("message", "일반 계정으로 두고 제안에서 뺐어요.");
    return redirectToAnalytics(weeks, includeAll);
  }

  // 종류 확인 > 바꾸기 > 바뀌었으면 관리자 기록(전 > 후) + 안내
  private void changeAccountKind(
    String memberId, String accountKindParameter, Principal principal, RedirectAttributes redirectAttributes
  ) {
    MemberAccountKind newKind = MemberAccountKind.fromParameterOrNull(accountKindParameter);
    if (newKind == null) {
      log.info("[admin account kind] rejected 400 : unknown kind, memberId={}", AdminLogIds.toLoggableId(memberId));
      redirectAttributes.addFlashAttribute("errorMessage",
        "계정 종류를 다시 골라 주세요. (" + INVALID_KIND_ERROR_CODE + ")");
      return;
    }
    MemberAccountKindChange change = memberAccountKindService.changeAccountKind(
      memberId, newKind, AdminActor.nameOf(principal));
    if (!change.isChanged()) {
      redirectAttributes.addFlashAttribute("message", "이미 " + newKind.getLabel() + " 계정이에요.");
      return;
    }
    log.info("[admin account kind] changed : memberId={}, {} -> {}, admin={}", AdminLogIds.toLoggableId(memberId),
      change.previousKind(), change.currentKind(), AdminActor.nameOf(principal));
    adminAuditService.record(AdminAuditAction.MEMBER_ACCOUNT_KIND_CHANGED, memberId,
      change.previousKind().getLabel() + " > " + change.currentKind().getLabel());
    redirectAttributes.addFlashAttribute("message",
      "계정 종류를 " + newKind.getLabel() + "(으)로 바꿨어요. 관리자 숫자에서 " + countingTextOf(newKind));
  }

  private static String countingTextOf(MemberAccountKind kind) {
    return kind == MemberAccountKind.NORMAL ? "다시 세요." : "빠져요.";
  }

  // 사용 분석으로 돌아감 (기간·모두 포함은 화면 값 그대로, 검증은 화면이 다시 함)
  private static String redirectToAnalytics(String weeks, String includeAll) {
    UriComponentsBuilder builder = UriComponentsBuilder.fromPath(ANALYTICS_PATH);
    if (weeks != null) {
      builder.queryParam("weeks", weeks);
    }
    if ("true".equalsIgnoreCase(includeAll)) {
      builder.queryParam("includeAll", "true");
    }
    return "redirect:" + builder.encode().build().toUriString();
  }
}
