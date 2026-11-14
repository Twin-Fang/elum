package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.request.ConsentEditForm;
import com.chuseok22.elumserver.admin.application.dto.response.ConsentLocaleView;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 약관 관리 화면 언어 탭·번역본 만들기가 실제로 그려지는지 (#1379, 스프링 컨텍스트 없음)
 */
class AdminConsentTemplateTest {

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  private ConsentDocument document(ConsentKey key, String locale) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setLocale(locale);
    document.setVersion("2026-10-01");
    document.setLabel("Terms of Service");
    document.setSummary("How you use ELUM");
    document.setBody("Body");
    document.setRequired(key.isRequired());
    document.setPublishedAt(LocalDateTime.of(2026, 10, 1, 0, 0));
    // 감사 컬럼은 JPA 가 채움, 화면 확인용으로 직접 넣음
    ReflectionTestUtils.setField(document, "updatedAt", LocalDateTime.of(2026, 10, 2, 9, 0));
    return document;
  }

  @Test
  @DisplayName("번역본 탭: 있는 행은 언어 붙은 고치기·이력 링크, 없는 행은 만들기 링크")
  void list_translationTab_rendersExistingAndMissingRows() {
    Map<String, Object> variables = new HashMap<>();
    variables.put("documents", List.of(document(ConsentKey.TERMS, "en")));
    variables.put("missingKeys", List.of(ConsentKey.MARKETING));
    variables.put("bundleVersion", "2026-10-01");
    variables.put("locales", Arrays.stream(AppLocale.values())
      .map(locale -> ConsentLocaleView.of(locale, locale == AppLocale.KO ? 0 : 1, locale == AppLocale.KO))
      .toList());
    variables.put("selectedLocale", "en");
    variables.put("isSelectedLocalePublished", false);

    String html = renderer.render("admin/consents", variables);

    assertThat(html)
      .contains("/admin/consents?locale=ja")
      .contains("/admin/consents/TERMS?locale=en")
      .contains("/admin/consents/TERMS/history?locale=en")
      .contains("/admin/consents/MARKETING?locale=en")
      .contains("만들기").contains("게시됨").contains("ko로 대체")
      .contains("지금은 한국어로 대체 중");
  }

  @Test
  @DisplayName("번역본 새로 만들기 화면: 언어 hidden 칸이 실리고 버전 올리기 칸은 없다")
  void edit_newTranslation_rendersLocaleFieldWithoutBump() {
    Map<String, Object> variables = new HashMap<>();
    variables.put("consentKey", ConsentKey.TERMS);
    variables.put("selectedLocale", "en");
    variables.put("isNewTranslation", true);
    variables.put("title", ConsentKey.TERMS.getLabel());
    variables.put("version", "2026-10-01");
    variables.put("document", null);
    variables.put("form", ConsentEditForm.empty("2026-11-14"));

    String html = renderer.render("admin/consent-edit", variables);

    assertThat(html)
      .contains("name=\"locale\" value=\"en\"")
      .contains("action=\"/admin/consents/TERMS\"")
      .contains("name=\"label\"").contains("name=\"summary\"").contains("name=\"body\"").contains("name=\"reason\"")
      .contains("아직 이 약관이 없어요")
      .doesNotContain("name=\"bumpVersion\"")
      .doesNotContain("/admin/consents/TERMS/history");
  }
}
