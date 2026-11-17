package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.DraftRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.ProductRow;
import com.chuseok22.elumserver.admin.application.service.AdminCreditPackService;
import com.chuseok22.elumserver.admin.application.service.AdminCreditPackService.DraftCheck;
import com.chuseok22.elumserver.admin.application.service.AdminCreditPackService.SaleChange;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.security.Principal;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 관리자 AI 크레딧 > 꾸러미 (#1442): 스토어별 판매 켜기·끄기, 상품 편집(미리보기 > 저장), 설정 점검
 * 판매를 바꾸면 사유 필수, 미리보기와 틀린 저장은 입력값을 그대로 둔 채 같은 화면으로 돌려줌
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class AdminCreditPackController {

  static final String PACKS_PATH = "/admin/credits/packs";
  private static final String SAVE_FAILED_CODE = "ADMIN-CREDIT-PACKS-SAVE";

  private final AdminCreditPackService packService;

  @GetMapping(PACKS_PATH)
  public String packs(Model model) {
    AdminCreditPackView view = packService.view();
    populate(model, view, draftRowsOf(view), popularOf(view), null);
    return "admin/credits-packs";
  }

  /// 스토어 판매 켜기·끄기 (사유 필수) > 결과 문구
  @PostMapping(PACKS_PATH + "/sale")
  public String changeSale(
    @RequestParam("store") String store,
    @RequestParam("enabled") boolean isEnabled,
    @RequestParam(name = "reason", required = false) String reason,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    SubscriptionSource source = storeOf(store);
    SaleChange result = source == null
      ? new SaleChange(false, "알 수 없는 스토어예요 (" + SAVE_FAILED_CODE + ")")
      : packService.setStoreSale(source, isEnabled, AdminActor.nameOf(principal), reason);
    redirectAttributes.addFlashAttribute(result.isChanged() ? "message" : "errorMessage", result.message());
    return "redirect:" + PACKS_PATH;
  }

  /// 저장 없이 검사 + 미리보기 (입력값은 그대로 화면에 남김)
  @PostMapping(PACKS_PATH + "/preview")
  public String preview(
    @RequestParam(name = "productId", required = false) List<String> productIds,
    @RequestParam(name = "credits", required = false) List<String> credits,
    @RequestParam(name = "popularProductId", required = false) String popularProductId,
    Model model
  ) {
    List<DraftRow> draftRows = draftRowsOf(productIds, credits);
    DraftCheck check = packService.checkDraft(draftRows, popularProductId);
    populate(model, packService.view(), draftRows, popularProductId, check);
    model.addAttribute(check.isValid() ? "message" : "errorMessage", check.message());
    return "admin/credits-packs";
  }

  /// 상품 목록과 인기 상품 저장 (사유 필수): 성공이면 새로고침 화면, 거절이면 입력값을 둔 채 사유 표시
  @PostMapping(PACKS_PATH + "/save")
  public String save(
    @RequestParam(name = "productId", required = false) List<String> productIds,
    @RequestParam(name = "credits", required = false) List<String> credits,
    @RequestParam(name = "popularProductId", required = false) String popularProductId,
    @RequestParam(name = "reason", required = false) String reason,
    Principal principal,
    Model model,
    RedirectAttributes redirectAttributes
  ) {
    List<DraftRow> draftRows = draftRowsOf(productIds, credits);
    DraftCheck result;
    try {
      result = packService.saveDraft(draftRows, popularProductId, AdminActor.nameOf(principal), reason);
    } catch (CustomException e) {
      log.warn("[credit pack admin] save rejected : {}", e.getErrorCode());
      result = DraftCheck.rejectedWith("저장하지 못했어요: " + (e.getDetail() == null ? "값이 올바르지 않아요" : e.getDetail()) + " (" + SAVE_FAILED_CODE + ")");
    }
    if (result.isValid()) {
      redirectAttributes.addFlashAttribute("message", result.message());
      return "redirect:" + PACKS_PATH;
    }
    populate(model, packService.view(), draftRows, popularProductId, null);
    model.addAttribute("errorMessage", result.message());
    return "admin/credits-packs";
  }

  private void populate(Model model, AdminCreditPackView view, List<DraftRow> draftRows, String popularProductId, DraftCheck preview) {
    model.addAttribute("view", view);
    model.addAttribute("draftRows", draftRows);
    model.addAttribute("popularProductId", popularProductId == null ? "" : popularProductId);
    model.addAttribute("previewRows", preview != null && preview.isValid() ? preview.previewRows() : List.<ProductRow>of());
    model.addAttribute("isPreviewShown", preview != null && preview.isValid());
  }

  /// 현재 설정 > 편집 입력 줄 (설정을 못 읽었으면 빈 줄 하나)
  private static List<DraftRow> draftRowsOf(AdminCreditPackView view) {
    if (view.products() == null || view.products().rows().isEmpty()) {
      return List.of(new DraftRow("", ""));
    }
    return view.products().rows().stream().map(row -> new DraftRow(row.productId(), String.valueOf(row.credits()))).toList();
  }

  private static String popularOf(AdminCreditPackView view) {
    return view.products() == null ? "" : view.products().popularProductId();
  }

  /// 같은 이름 입력칸 두 묶음 > 줄 (짧은 쪽 길이까지, 줄이 하나도 없으면 빈 줄 하나)
  private static List<DraftRow> draftRowsOf(List<String> productIds, List<String> credits) {
    List<DraftRow> rows = new ArrayList<>();
    int size = productIds == null || credits == null ? 0 : Math.min(productIds.size(), credits.size());
    for (int index = 0; index < size; index++) {
      rows.add(new DraftRow(productIds.get(index), credits.get(index)));
    }
    return rows.isEmpty() ? List.of(new DraftRow("", "")) : rows;
  }

  private static SubscriptionSource storeOf(String raw) {
    try {
      return SubscriptionSource.valueOf(raw.trim());
    } catch (IllegalArgumentException | NullPointerException e) {
      return null;
    }
  }
}
