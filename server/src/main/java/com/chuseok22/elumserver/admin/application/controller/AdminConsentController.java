package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.ConsentEditForm;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.UpdateResult;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import java.security.Principal;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import jakarta.servlet.http.HttpServletResponse;

/**
 * 약관을 관리자 화면에서 고친다 (이슈 #278).
 *
 * <p>전에는 문구 한 줄을 고치려 해도 앱을 다시 빌드해 심사를 받아야 했다.
 */
@Controller
@RequiredArgsConstructor
public class AdminConsentController {

  private final ConsentDocumentService consentDocumentService;

  @GetMapping("/admin/consents")
  public String list(Model model) {
    model.addAttribute("documents", consentDocumentService.getAll());
    model.addAttribute("bundleVersion", consentDocumentService.bundleVersion());
    return "admin/consents";
  }

  @GetMapping("/admin/consents/{key}")
  public String edit(@PathVariable ConsentKey key, Model model) {
    var document = consentDocumentService.get(key);
    model.addAttribute("document", document);
    model.addAttribute("form", ConsentEditForm.of(document, LocalDate.now().toString()));
    return "admin/consent-edit";
  }

  @GetMapping("/admin/consents/{key}/history")
  public String history(@PathVariable ConsentKey key, Model model) {
    model.addAttribute("document", consentDocumentService.get(key));
    model.addAttribute("histories", consentDocumentService.getHistory(key));
    return "admin/consent-history";
  }

  /**
   * 저장한다. 필수 여부는 받지 않는다 — 법이 정한 값이라 관리자가 바꿀 수 없다.
   *
   * <p><b>검증에 걸리면 리다이렉트하지 않고 입력한 값 그대로 다시 그린다.</b>
   * 리다이렉트하면 DB 값을 다시 읽어 고치던 전문이 사라진다.
   */
  @PostMapping("/admin/consents/{key}")
  public String update(
    @PathVariable ConsentKey key,
    @RequestParam("label") String label,
    @RequestParam("summary") String summary,
    @RequestParam("body") String body,
    @RequestParam(value = "bumpVersion", defaultValue = "false") boolean bumpVersion,
    @RequestParam(value = "newVersion", required = false) String newVersion,
    @RequestParam(value = "reason", defaultValue = "") String reason,
    Principal principal,
    Model model,
    HttpServletResponse response,
    RedirectAttributes redirectAttributes
  ) {
    UpdateResult result;
    try {
      result = consentDocumentService.update(
        key, label, summary, body, bumpVersion, newVersion,
        principal == null ? null : principal.getName(), reason);
    } catch (CustomException e) {
      var document = consentDocumentService.get(key);
      model.addAttribute("document", document);
      model.addAttribute("form",
        new ConsentEditForm(label, summary, body, bumpVersion, newVersion, reason));
      model.addAttribute("errorMessage", failureReason(e));
      // 화면은 그대로 그리되 상태 코드는 실패로 둔다. 200으로 두면 모니터링이 성공으로 센다.
      response.setStatus(HttpStatus.BAD_REQUEST.value());
      return "admin/consent-edit";
    }

    String name = label.strip();
    String message = switch (result) {
      case UNCHANGED -> "바뀐 내용이 없어 저장하지 않았습니다.";
      case SAVED -> name + objectParticle(name) + " 저장했습니다.";
      case SAVED_AND_BUMPED -> name + objectParticle(name) + " 저장하고 버전을 올렸습니다. 새 버전 "
        + consentDocumentService.get(key).getVersion();
    };
    redirectAttributes.addFlashAttribute("message", message);
    return "redirect:/admin/consents";
  }

  /** 오류마다 무엇을 고치면 되는지와 추적용 코드를 함께 준다. */
  private String failureReason(CustomException e) {
    return switch (e.getErrorCode()) {
      case CONSENT_REASON_REQUIRED ->
        "수정 사유를 적어주세요. 약관은 법적 문서라 변경 근거가 남아야 합니다. (E-CNS-001)";
      case CONSENT_FIELD_BLANK ->
        "항목 이름·요약·전문은 비워둘 수 없습니다. 하나라도 비면 앱이 서버 약관 전체를 버립니다. (E-CNS-002)";
      case CONSENT_FIELD_TOO_LONG ->
        "항목 이름과 요약은 " + ConsentDocumentService.TEXT_FIELD_MAX_LENGTH
          + "자까지 적을 수 있습니다. (E-CNS-003)";
      case CONSENT_VERSION_REQUIRED ->
        "버전을 올리려면 새 버전을 적어주세요. (E-CNS-004)";
      case CONSENT_VERSION_INVALID ->
        "버전은 2026-09-21 같은 날짜로 적어주세요. (E-CNS-005)";
      case CONSENT_VERSION_NOT_NEWER ->
        "새 버전은 지금 버전보다 늦은 날짜여야 합니다. (E-CNS-006)";
      default -> "저장하지 못했습니다. (E-CNS-000)";
    };
  }

  /**
   * 목적격 조사. 항목 이름이 다섯 개인데 받침이 제각각이라 하나로 고정할 수 없다
   * ({@code 이용약관}은 "을", {@code 만 14세 이상입니다}는 "를"). {@code 을(를)}로
   * 뭉뚱그리면 관공서 문투가 된다.
   *
   * <p>한글이 아닌 글자로 끝나면 "을"을 준다 — 틀릴 수는 있어도 화면이 깨지지는 않는다.
   */
  private String objectParticle(String word) {
    if (word == null || word.isBlank()) {
      return "을";
    }
    char last = word.strip().charAt(word.strip().length() - 1);
    if (last < 0xAC00 || last > 0xD7A3) {
      return "을";
    }
    // 한글 음절은 (초성, 중성, 종성) 조합이고 종성 자리가 28칸이다. 나머지가 0이면 받침이 없다.
    return (last - 0xAC00) % 28 == 0 ? "를" : "을";
  }
}
