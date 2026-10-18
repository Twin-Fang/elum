package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.PromptLocaleView;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/** 프롬프트 화면의 언어 탭·안내·행 만들기 (스펙 4.5). 서버를 띄우지 않고 템플릿만 그린다. */
class AdminPromptsLocaleTemplateTest {

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  private String render(String template, Context context) {
    return renderer.render(template, context);
  }

  private PromptTemplate row(PromptKey key, String locale) {
    PromptTemplate prompt = new PromptTemplate();
    prompt.setPromptKey(key);
    prompt.setLocale(locale);
    prompt.setContent("지시문");
    return prompt;
  }

  private List<PromptLocaleView> views() {
    return List.of(
      PromptLocaleView.of(AppLocale.KO, true, 0),
      PromptLocaleView.of(AppLocale.EN, true, 0),
      PromptLocaleView.of(AppLocale.ES, false, 3));
  }

  @Test
  @DisplayName("켜지지 않았고 행이 모자란 es 탭: 탭 링크·꺼짐 안내·행 만들기 폼이 보이고 저장 폼은 es 로 간다")
  void disabledLocaleWithMissingRows() {
    Context context = new Context();
    context.setVariable("prompts", List.of(row(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "es")));
    context.setVariable("locales", views());
    context.setVariable("selectedLocale", "es");
    context.setVariable("localeEnabled", false);
    context.setVariable("missingKeys", List.of(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE));

    String html = render("admin/prompts", context);

    assertThat(html).contains("href=\"/admin/prompts?locale=es\"").contains("href=\"/admin/prompts?locale=en\"");
    assertThat(html).contains("켜지지 않았어요");
    assertThat(html).contains("기본값으로 행 만들기").contains("action=\"/admin/prompts/locales/es/seed\"");
    assertThat(html).contains("action=\"/admin/prompts/GEMINI_ROUTINE_CREATE_PREFIX?locale=es\"");
    assertThat(html).contains("/admin/prompts/GEMINI_ROUTINE_CREATE_PREFIX/history?locale=es");
    assertThat(html).contains("data-locale=\"es\"");
  }

  @Test
  @DisplayName("켜져 있고 행이 다 있는 en 탭: 꺼짐 안내도 행 만들기 폼도 없다")
  void enabledCompleteLocale() {
    Context context = new Context();
    context.setVariable("prompts", List.of(row(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "en")));
    context.setVariable("locales", views());
    context.setVariable("selectedLocale", "en");
    context.setVariable("localeEnabled", true);
    context.setVariable("missingKeys", List.of());

    String html = render("admin/prompts", context);

    assertThat(html).doesNotContain("켜지지 않았어요").doesNotContain("기본값으로 행 만들기");
    assertThat(html).contains("data-locale=\"en\"");
  }

  @Test
  @DisplayName("언어 모델이 없어도(옛 호출) ko 화면으로 그려진다 — 깨지지 않는다")
  void minimalContextRendersAsKo() {
    Context context = new Context();
    context.setVariable("prompts", List.of(row(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "ko")));

    String html = render("admin/prompts", context);

    assertThat(html).contains("data-locale=\"ko\"").doesNotContain("기본값으로 행 만들기");
    assertThat(html).contains("action=\"/admin/prompts/GEMINI_ROUTINE_CREATE_PREFIX?locale=ko\"");
  }

  @Test
  @DisplayName("시험 버튼 옆에 비용 안내가 있다 — 운영 AI 를 실제로 부른다")
  void testButtonWarnsAboutCost() {
    Context context = new Context();
    context.setVariable("prompts", List.of(row(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "ko")));

    assertThat(render("admin/prompts", context)).contains("운영 AI").contains("비용");
  }

  @Test
  @DisplayName("이력 화면: 제목에 언어가 보이고 복원 폼과 돌아가기 링크가 같은 언어로 간다")
  void historyKeepsTheLocale() {
    PromptTemplateHistory history = new PromptTemplateHistory();
    history.setPromptKey(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    history.setLocale("es");
    history.setContent("이전 es");
    Context context = new Context();
    context.setVariable("prompt", row(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "es"));
    context.setVariable("histories", List.of(history));
    context.setVariable("selectedLocale", "es");

    String html = render("admin/prompt-history", context);

    assertThat(html).contains("(es)");
    assertThat(html).contains("action=\"/admin/prompts/GEMINI_ROUTINE_CREATE_PREFIX?locale=es\"");
    assertThat(html).contains("href=\"/admin/prompts?locale=es\"");
  }

  @Test
  @DisplayName("en 탭: 저장 폼은 선택된 en 으로 간다 — 보내지 않으면 운영 ko 행이 덮인다")
  void saveFormCarriesSelectedLocale() {
    Context context = new Context();
    context.setVariable("prompts", List.of(row(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "en")));
    context.setVariable("selectedLocale", "en");

    String html = render("admin/prompts", context);

    assertThat(html).contains("action=\"/admin/prompts/GEMINI_ROUTINE_CREATE_PREFIX?locale=en\"");
    assertThat(html).doesNotContain("?locale=ko");
  }

  @Test
  @DisplayName("행 만들기 폼: 제출하면 버튼이 잠겨 두 번 눌러도 한 번만 간다")
  void seedButtonLocksOnSubmit() {
    Context context = new Context();
    context.setVariable("prompts", List.of(row(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "es")));
    context.setVariable("selectedLocale", "es");
    context.setVariable("localeEnabled", false);
    context.setVariable("missingKeys", List.of(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE));

    String html = render("admin/prompts", context);

    assertThat(html).contains("disabled = true");
  }

  @Test
  @DisplayName("시험·미리보기 본문에 locale 이 실린다")
  void testAndPreviewBodiesCarryLocale() {
    Context context = new Context();
    context.setVariable("prompts", List.of(row(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "en")));

    String html = render("admin/prompts", context);

    assertThat(html).contains("function currentLocale()");
    assertThat(html.split("locale: currentLocale\\(\\)", -1).length - 1).isEqualTo(2);
  }
}
