package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminCreditPurchaseService;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPurchaseAdminQueryService.PurchaseFilter;
import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler.ConsumableRefundOutcome;
import com.chuseok22.elumserver.license.core.ConsumableRefundResult;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StoreRefundCheckRun;
import java.security.Principal;
import java.util.List;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 관리자 AI 크레딧 > 구매·환불 (#1428): 크레딧 꾸러미 구매 목록·필터, 건별 수동 회수, 스토어 환불 재확인 기록·지금 확인
 * 필터 값은 문자열로 받아 직접 해석 (틀린 값은 필터 없음으로, 400 화면 대신)
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminCreditPurchaseController {

  static final String LIST_PATH = "/admin/credits/purchases";
  /// 화면 오류 코드 (제보 추적용)
  private static final String REVOKE_NOT_FOUND_CODE = "ADMIN-CREDIT-PURCHASE-NOT-FOUND";
  private static final String REVOKE_REASON_REQUIRED_CODE = "ADMIN-CREDIT-PURCHASE-REASON";
  private static final String RECHECK_FAILED_CODE = "ADMIN-REFUND-RECHECK";
  private static final int REVOKE_REASON_MAX_LENGTH = 200;

  private final AdminCreditPurchaseService purchaseService;

  @GetMapping(LIST_PATH)
  public String list(
    @RequestParam(name = "store", required = false) String store,
    @RequestParam(name = "status", required = false) String status,
    @RequestParam(name = "q", required = false) String q,
    @RequestParam(name = "page", defaultValue = "0") int page,
    Model model
  ) {
    PurchaseFilter filter = new PurchaseFilter(enumOf(SubscriptionSource.class, store),
      enumOf(CreditPurchaseStatus.class, status), q);
    model.addAttribute("rows", purchaseService.search(filter, page));
    model.addAttribute("filter", filter);
    model.addAttribute("q", q == null ? "" : q);
    model.addAttribute("stores", List.of(SubscriptionSource.APPLE_IAP, SubscriptionSource.GOOGLE_IAP));
    model.addAttribute("statuses", CreditPurchaseStatus.values());
    model.addAttribute("recheck", purchaseService.recheckOverview());
    return "admin/credits-purchases";
  }

  /// 건별 수동 회수: 사유 필수, 결과는 flash 문구로
  @PostMapping(LIST_PATH + "/{purchaseId}/revoke")
  public String revoke(
    @PathVariable String purchaseId,
    @RequestParam(name = "reason", required = false) String reason,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    if (reason == null || reason.isBlank() || reason.length() > REVOKE_REASON_MAX_LENGTH) {
      redirectAttributes.addFlashAttribute("errorMessage",
        "회수하지 못했어요: 사유를 200자 안으로 적어 주세요 (" + REVOKE_REASON_REQUIRED_CODE + ")");
      return "redirect:" + LIST_PATH;
    }
    ConsumableRefundOutcome outcome = purchaseService.revoke(purchaseId, AdminActor.nameOf(principal), reason);
    if (outcome.result() == ConsumableRefundResult.UNKNOWN) {
      redirectAttributes.addFlashAttribute("errorMessage", "회수하지 못했어요: 구매 기록이 없어요 (" + REVOKE_NOT_FOUND_CODE + ")");
    } else if (outcome.result() == ConsumableRefundResult.ALREADY_REFUNDED) {
      redirectAttributes.addFlashAttribute("message", "이미 환불로 처리된 구매예요. 바뀐 것은 없어요.");
    } else {
      redirectAttributes.addFlashAttribute("message", "회수했어요. 남은 구매 크레딧을 0으로 맞추고 원장에 남겼어요.");
    }
    return "redirect:" + LIST_PATH;
  }

  /// 지금 확인: 두 스토어 재확인 1회 > 결과 요약 문구
  @PostMapping(LIST_PATH + "/refund-recheck")
  public String runRecheck(Principal principal, RedirectAttributes redirectAttributes) {
    try {
      List<StoreRefundCheckRun> runs = purchaseService.runRecheckNow(AdminActor.nameOf(principal));
      redirectAttributes.addFlashAttribute("message", "환불 재확인을 마쳤어요. " + summaryOf(runs));
    } catch (RuntimeException e) {
      log.error("[refund recheck] admin run failed : cause={}", e.getClass().getSimpleName(), e);
      redirectAttributes.addFlashAttribute("errorMessage", "환불 재확인을 하지 못했어요 (" + RECHECK_FAILED_CODE + ")");
    }
    return "redirect:" + LIST_PATH;
  }

  // "App Store 결제: 회수 1건 · Google Play 결제: 실패(스토어 API 키 없음)"
  private static String summaryOf(List<StoreRefundCheckRun> runs) {
    return runs.stream()
      .map(run -> run.getStore().getLabel() + ": " + (run.isSucceeded()
        ? "회수 " + run.getRevokedCount() + "건"
        : "실패(" + run.getFailureReason().getLabel() + "), 회수 " + run.getRevokedCount() + "건"))
      .collect(Collectors.joining(" · "));
  }

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
}
