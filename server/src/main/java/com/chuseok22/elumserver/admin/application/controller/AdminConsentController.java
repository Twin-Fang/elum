package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import java.security.Principal;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

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
    model.addAttribute("document", consentDocumentService.get(key));
    // 버전을 올리기로 했을 때 채워 넣을 기본값. 버전은 날짜 문자열을 쓴다.
    model.addAttribute("today", LocalDate.now().toString());
    return "admin/consent-edit";
  }

  @GetMapping("/admin/consents/{key}/history")
  public String history(@PathVariable ConsentKey key, Model model) {
    model.addAttribute("document", consentDocumentService.get(key));
    model.addAttribute("histories", consentDocumentService.getHistory(key));
    return "admin/consent-history";
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

  /**
   * @param bumpVersion 체크했을 때만 버전을 올린다. <b>오타 수정까지 버전을 올리면</b>
   *                    사용자가 재동의 화면을 반복해서 보게 된다.
   */
  @PostMapping("/admin/consents/{key}")
  public String update(
    @PathVariable ConsentKey key,
    @RequestParam("label") String label,
    @RequestParam("summary") String summary,
    @RequestParam("body") String body,
    @RequestParam(value = "required", defaultValue = "false") boolean required,
    @RequestParam(value = "bumpVersion", defaultValue = "false") boolean bumpVersion,
    @RequestParam(value = "newVersion", required = false) String newVersion,
    @RequestParam("reason") String reason,
    Principal principal,
    RedirectAttributes redirectAttributes
  ) {
    if (reason == null || reason.isBlank()) {
      // 법적 문구라 "왜 바꿨는지"가 곧 근거다. 사유 없는 수정은 받지 않는다.
      redirectAttributes.addFlashAttribute("errorMessage",
        "수정 사유를 적어주세요. 약관은 법적 문서라 변경 근거가 남아야 합니다. (E-CNS-001)");
      return "redirect:/admin/consents/" + key.name();
    }

    consentDocumentService.update(
      key, label, summary, body, required,
      bumpVersion ? newVersion : null,
      principal == null ? null : principal.getName(),
      reason
    );

    redirectAttributes.addFlashAttribute("message",
      label + objectParticle(label) + " 저장했습니다." + (bumpVersion ? " 버전을 올렸습니다." : ""));
    return "redirect:/admin/consents";
  }
}
