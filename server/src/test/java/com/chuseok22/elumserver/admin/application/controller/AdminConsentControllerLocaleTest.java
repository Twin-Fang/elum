package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.request.ConsentEditForm;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.UpdateResult;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.ui.ExtendedModelMap;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/**
 * 약관 관리 언어 선택 (#1379): 모르는 언어는 거절(E-CNS-007), 고른 언어는 서비스까지 그대로
 */
class AdminConsentControllerLocaleTest {

  private ConsentDocumentService consentDocumentService;
  private AdminConsentController controller;

  @BeforeEach
  void setUp() {
    consentDocumentService = mock(ConsentDocumentService.class);
    when(consentDocumentService.getAll(any())).thenReturn(List.of());
    when(consentDocumentService.missingKeys(any())).thenReturn(List.of());
    when(consentDocumentService.resolvePublishedLocale(any())).thenReturn(AppLocale.KO);
    controller = new AdminConsentController(consentDocumentService);
  }

  private ConsentDocument document(ConsentKey key, String locale, String version) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setLocale(locale);
    document.setVersion(version);
    document.setLabel("Terms of Service");
    document.setSummary("Summary");
    document.setBody("Body");
    document.setRequired(key.isRequired());
    document.setPublishedAt(LocalDateTime.of(2026, 10, 1, 0, 0));
    return document;
  }

  private String post(String locale, RedirectAttributesModelMap redirect) {
    return controller.update(ConsentKey.TERMS, locale, "Terms of Service", "Summary", "Body",
      false, null, "번역 게시", null, new ExtendedModelMap(), new MockHttpServletResponse(), redirect);
  }

  @ParameterizedTest
  @ValueSource(strings = {"xx", "", "  ", "en-US"})
  @DisplayName("모르는·빈 언어 코드로 저장하면 거절한다 — 번역 내용이 ko 원본을 덮어쓰지 않게")
  void update_unknownLocale_rejected(String locale) {
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    String view = post(locale, redirect);

    assertThat(view).isEqualTo("redirect:/admin/consents");
    assertThat((String) redirect.getFlashAttributes().get("errorMessage")).contains("E-CNS-007");
    verify(consentDocumentService, never())
      .update(any(), any(AppLocale.class), any(), any(), any(), anyBoolean(), any(), any(), any());
  }

  @Test
  @DisplayName("고른 언어가 서비스까지 그대로 가고, 저장 뒤 그 언어 탭으로 돌아간다")
  void update_localePassedThrough() {
    when(consentDocumentService.update(eq(ConsentKey.TERMS), eq(AppLocale.EN), anyString(), anyString(),
      anyString(), anyBoolean(), isNull(), isNull(), anyString())).thenReturn(UpdateResult.CREATED);
    when(consentDocumentService.get(ConsentKey.TERMS, AppLocale.EN))
      .thenReturn(document(ConsentKey.TERMS, "en", "2026-10-01"));
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    String view = post(" EN ", redirect);

    assertThat(view).isEqualTo("redirect:/admin/consents?locale=en");
    assertThat((String) redirect.getFlashAttributes().get("message"))
      .contains("(en) 번역본을 새로 만들었습니다").contains("2026-10-01");
  }

  @Test
  @DisplayName("언어 파라미터가 없으면 ko 로 저장하고 기존 주소로 돌아간다 — 기존 ko 화면 동작 유지")
  void update_noLocale_isKo() {
    when(consentDocumentService.update(eq(ConsentKey.TERMS), eq(AppLocale.KO), anyString(), anyString(),
      anyString(), anyBoolean(), isNull(), isNull(), anyString())).thenReturn(UpdateResult.SAVED);
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    String view = post(null, redirect);

    assertThat(view).isEqualTo("redirect:/admin/consents");
    assertThat((String) redirect.getFlashAttributes().get("message")).isEqualTo("Terms of Service을 저장했습니다.");
  }

  @Test
  @DisplayName("모르는 언어로 목록을 열면 조회 없이 ko 목록으로 돌려보낸다")
  void list_unknownLocale_redirected() {
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    String view = controller.list("fr", new ExtendedModelMap(), redirect);

    assertThat(view).isEqualTo("redirect:/admin/consents");
    assertThat((String) redirect.getFlashAttributes().get("errorMessage")).contains("E-CNS-007").contains("fr");
    verifyNoInteractions(consentDocumentService);
  }

  @Test
  @DisplayName("목록은 고른 언어의 약관과 없는 항목, 언어 탭 5칸을 싣는다")
  void list_selectedLocale() {
    when(consentDocumentService.missingKeys(AppLocale.JA)).thenReturn(List.of(ConsentKey.MARKETING));
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.list("ja", model, new RedirectAttributesModelMap());

    assertThat(view).isEqualTo("admin/consents");
    assertThat(model.getAttribute("selectedLocale")).isEqualTo("ja");
    assertThat(model.getAttribute("missingKeys")).isEqualTo(List.of(ConsentKey.MARKETING));
    assertThat((List<?>) model.getAttribute("locales")).hasSize(AppLocale.values().length);
    verify(consentDocumentService).getAll(AppLocale.JA);
  }

  @Test
  @DisplayName("없는 번역본 편집은 빈 칸 새로 만들기 화면 — 버전은 ko 원본 버전으로 보인다")
  void edit_missingTranslation_showsCreateForm() {
    when(consentDocumentService.find(ConsentKey.TERMS, AppLocale.ES)).thenReturn(Optional.empty());
    when(consentDocumentService.find(ConsentKey.TERMS, AppLocale.KO))
      .thenReturn(Optional.of(document(ConsentKey.TERMS, "ko", "2026-10-01")));
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.edit(ConsentKey.TERMS, "es", model, new RedirectAttributesModelMap());

    assertThat(view).isEqualTo("admin/consent-edit");
    assertThat(model.getAttribute("isNewTranslation")).isEqualTo(true);
    assertThat(model.getAttribute("version")).isEqualTo("2026-10-01");
    assertThat(model.getAttribute("selectedLocale")).isEqualTo("es");
    assertThat(((ConsentEditForm) model.getAttribute("form")).body()).isEmpty();
  }
}
