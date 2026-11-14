package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.ConsentEditForm;
import com.chuseok22.elumserver.admin.application.dto.response.ConsentLocaleView;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.text.HangulSyllables;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.UpdateResult;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import java.security.Principal;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
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
 * 약관을 관리자 화면에서 고친다.
 *
 * <p>문구 한 줄을 고치려고 앱을 다시 빌드해 심사받지 않아도 되게 한다.
 */
@Controller
@RequiredArgsConstructor
public class AdminConsentController {

  private static final String CONSENT_LIST_PATH = "/admin/consents";
  // 화면에 되돌려 보이는 언어 코드 최대 길이
  private static final int ECHOED_LOCALE_MAX_LENGTH = 20;

  private final ConsentDocumentService consentDocumentService;

  @GetMapping("/admin/consents")
  public String list(
    @RequestParam(value = "locale", required = false) String locale,
    Model model,
    RedirectAttributes redirectAttributes
  ) {
    Optional<AppLocale> parsed = parseLocaleStrict(locale);
    if (parsed.isEmpty()) {
      return rejectUnknownLocale(locale, redirectAttributes);
    }
    // 언어 5개 모두 편집 (번역본 게시 #1379)
    AppLocale selected = parsed.get();
    model.addAttribute("documents", consentDocumentService.getAll(selected));
    model.addAttribute("missingKeys", consentDocumentService.missingKeys(selected));
    model.addAttribute("bundleVersion", consentDocumentService.bundleVersion(selected));
    model.addAttribute("locales", localeViews());
    model.addAttribute("selectedLocale", selected.code());
    model.addAttribute("isSelectedLocalePublished",
      consentDocumentService.resolvePublishedLocale(selected) == selected);
    return "admin/consents";
  }

  @GetMapping("/admin/consents/{key}")
  public String edit(
    @PathVariable ConsentKey key,
    @RequestParam(value = "locale", required = false) String locale,
    Model model,
    RedirectAttributes redirectAttributes
  ) {
    Optional<AppLocale> parsed = parseLocaleStrict(locale);
    if (parsed.isEmpty()) {
      return rejectUnknownLocale(locale, redirectAttributes);
    }
    AppLocale selected = parsed.get();
    String today = LocalDate.now().toString();
    // ko 는 행이 없으면 404 (기동 시딩 대상), 번역본은 없으면 새로 만들기 화면
    Optional<ConsentDocument> document = selected == AppLocale.KO
      ? Optional.of(consentDocumentService.get(key, AppLocale.KO))
      : consentDocumentService.find(key, selected);
    ConsentEditForm form = document.map(found -> ConsentEditForm.of(found, today))
      .orElseGet(() -> ConsentEditForm.empty(today));
    addEditModel(model, key, selected, document, form);
    return "admin/consent-edit";
  }

  @GetMapping("/admin/consents/{key}/history")
  public String history(
    @PathVariable ConsentKey key,
    @RequestParam(value = "locale", required = false) String locale,
    Model model,
    RedirectAttributes redirectAttributes
  ) {
    Optional<AppLocale> parsed = parseLocaleStrict(locale);
    if (parsed.isEmpty()) {
      return rejectUnknownLocale(locale, redirectAttributes);
    }
    AppLocale selected = parsed.get();
    model.addAttribute("document", consentDocumentService.get(key, selected));
    model.addAttribute("histories", consentDocumentService.getHistory(key, selected));
    model.addAttribute("selectedLocale", selected.code());
    return "admin/consent-history";
  }

  /**
   * 저장한다. 필수 여부는 받지 않는다 — 법이 정한 값이라 관리자가 바꿀 수 없다.
   * 번역본(ko 외)이 없으면 새로 만든다 (버전 = ko 원본 버전, 서비스 참고).
   *
   * <p><b>검증에 걸리면 리다이렉트하지 않고 입력한 값 그대로 다시 그린다.</b>
   * 리다이렉트하면 DB 값을 다시 읽어 고치던 전문이 사라진다.
   */
  @PostMapping("/admin/consents/{key}")
  public String update(
    @PathVariable ConsentKey key,
    @RequestParam(value = "locale", required = false) String locale,
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
    // 파라미터 없음만 ko, 빈 값·모르는 코드는 거절 (번역 내용이 ko 원본을 덮어쓰지 않도록)
    Optional<AppLocale> parsed = parseLocaleStrict(locale);
    if (parsed.isEmpty()) {
      return rejectUnknownLocale(locale, redirectAttributes);
    }
    AppLocale target = parsed.get();
    UpdateResult result;
    try {
      result = consentDocumentService.update(
        key, target, label, summary, body, bumpVersion, newVersion,
        principal == null ? null : principal.getName(), reason);
    } catch (CustomException e) {
      addEditModel(model, key, target, consentDocumentService.find(key, target),
        new ConsentEditForm(label, summary, body, bumpVersion, newVersion, reason));
      model.addAttribute("errorMessage", failureReason(e));
      // 화면은 그대로 그리되 상태 코드는 실패로 둔다. 200으로 두면 모니터링이 성공으로 센다.
      response.setStatus(HttpStatus.BAD_REQUEST.value());
      return "admin/consent-edit";
    }

    String name = target == AppLocale.KO
      ? label.strip()
      : key.getLabel() + " (" + target.code() + ") 번역본";
    String message = switch (result) {
      case UNCHANGED -> "바뀐 내용이 없어 저장하지 않았습니다.";
      case SAVED -> name + objectParticle(name) + " 저장했습니다.";
      case SAVED_AND_BUMPED -> name + objectParticle(name) + " 저장하고 버전을 올렸습니다. 새 버전 "
        + consentDocumentService.get(key, target).getVersion();
      case CREATED -> name + objectParticle(name) + " 새로 만들었습니다. 버전 "
        + consentDocumentService.get(key, target).getVersion() + " (ko 원본과 같음)";
    };
    redirectAttributes.addFlashAttribute("message", message);
    // ko 는 기존 주소 그대로, 번역본은 그 언어 탭으로
    return target == AppLocale.KO
      ? "redirect:" + CONSENT_LIST_PATH
      : "redirect:" + CONSENT_LIST_PATH + "?locale=" + target.code();
  }

  /** 편집 화면 모델: 대상 키·언어, 새 번역본 여부, 표시 버전(새 번역본은 ko 원본 버전) */
  private void addEditModel(
    Model model, ConsentKey key, AppLocale locale, Optional<ConsentDocument> document, ConsentEditForm form
  ) {
    boolean isNewTranslation = document.isEmpty();
    // 새 번역본 버전 = ko 원본 버전 (ko 원본마저 없으면 "-", 저장 시 E-CNS-008)
    String version = document.map(ConsentDocument::getVersion)
      .orElseGet(() -> consentDocumentService.find(key, AppLocale.KO).map(ConsentDocument::getVersion).orElse("-"));
    model.addAttribute("consentKey", key);
    model.addAttribute("selectedLocale", locale.code());
    model.addAttribute("isNewTranslation", isNewTranslation);
    model.addAttribute("title", document.map(ConsentDocument::getLabel).orElse(key.getLabel()));
    model.addAttribute("version", version);
    model.addAttribute("document", document.orElse(null));
    model.addAttribute("form", form);
  }

  /** 언어 탭 5칸: 없는 약관 수, 앱 게시 여부 */
  private List<ConsentLocaleView> localeViews() {
    return Arrays.stream(AppLocale.values())
      .map(locale -> ConsentLocaleView.of(locale,
        consentDocumentService.missingKeys(locale).size(),
        consentDocumentService.resolvePublishedLocale(locale) == locale))
      .toList();
  }

  /** 언어 코드 엄격 판정: 파라미터 없음 > ko, 앞뒤 공백·대소문자만 정규화, 빈 값·모르는 코드 > empty */
  private Optional<AppLocale> parseLocaleStrict(String code) {
    if (code == null) {
      return Optional.of(AppLocale.KO);
    }
    return AppLocale.findByCode(code.trim().toLowerCase(Locale.ROOT));
  }

  /** 모르는 언어 코드: 저장·조회 없이 ko 목록으로 (E-CNS-007) */
  private String rejectUnknownLocale(String code, RedirectAttributes redirectAttributes) {
    redirectAttributes.addFlashAttribute("errorMessage",
      "알 수 없는 언어 코드(" + sanitizeEchoedLocale(code) + ")예요. 언어 탭에서 다시 골라 주세요. (E-CNS-007)");
    return "redirect:" + CONSENT_LIST_PATH;
  }

  /** 화면에 되돌려 보이는 값 정리 (제어문자·꺾쇠·따옴표 > ?, 20자 제한) */
  private String sanitizeEchoedLocale(String code) {
    String cleaned = code == null ? "" : code.replaceAll("[\\p{Cntrl}<>\"']", "?");
    return cleaned.length() > ECHOED_LOCALE_MAX_LENGTH ? cleaned.substring(0, ECHOED_LOCALE_MAX_LENGTH) : cleaned;
  }

  /** 오류마다 무엇을 고치면 되는지와 추적용 코드를 함께 준다. */
  private String failureReason(CustomException e) {
    return switch (e.getErrorCode()) {
      case CONSENT_REASON_REQUIRED ->
        "수정 사유를 적어주세요. 약관은 법적 문서라 변경 근거가 남아야 합니다. (E-CNS-001)";
      case CONSENT_FIELD_BLANK ->
        "항목 이름·요약·전문은 비워둘 수 없어요. 하나라도 비면 앱이 서버 약관 전체를 버려요. (E-CNS-002)";
      case CONSENT_FIELD_TOO_LONG ->
        "항목 이름과 요약은 " + ConsentDocumentService.TEXT_FIELD_MAX_LENGTH
          + "자까지 적을 수 있습니다. (E-CNS-003)";
      case CONSENT_VERSION_REQUIRED ->
        "버전을 올리려면 새 버전을 적어주세요. (E-CNS-004)";
      case CONSENT_VERSION_INVALID ->
        "버전은 2026-09-21 같은 날짜로 적어주세요. (E-CNS-005)";
      case CONSENT_VERSION_NOT_NEWER ->
        "새 버전은 지금 버전보다 늦은 날짜여야 해요. (E-CNS-006)";
      case CONSENT_DOCUMENT_NOT_FOUND ->
        "ko 원본 약관이 없어 저장할 수 없어요. 서버를 다시 시작하면 ko 기본값이 채워집니다. (E-CNS-008)";
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
    if (!HangulSyllables.isHangulSyllable(last)) {
      return "을";
    }
    return HangulSyllables.hasJongseong(last) ? "을" : "를";
  }
}
