package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 프롬프트 화면 스크립트가 CSRF meta 없이도 멈추지 않는지 본다 (이슈 #399 후속).
 *
 * <p>#399 는 골격에서 meta 가 빠지자 스크립트 첫 줄 {@code querySelector(...).content} 가 null 에서
 * 예외를 던져 <b>버튼 처리기가 하나도 붙지 않았다</b> — 눌러도 아무 반응이 없고 서버 로그에도 흔적이
 * 없었다. meta 는 되살렸지만 스크립트가 같은 방식이면 다음에 빠질 때 똑같이 조용히 죽는다.
 * 토큰이 없으면 요청 때 화면에 새로고침 안내를 띄우도록 바꿨다. 토큰 없이 그린 화면을 확인한다.
 */
class AdminPromptsCsrfScriptTest {

  private String render() {
    ClassLoaderTemplateResolver resolver = new ClassLoaderTemplateResolver();
    resolver.setPrefix("templates/");
    resolver.setSuffix(".html");
    resolver.setTemplateMode(TemplateMode.HTML);
    resolver.setCharacterEncoding("UTF-8");
    SpringTemplateEngine engine = new SpringTemplateEngine();
    engine.setTemplateResolver(resolver);
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
    PromptTemplate prompt = new PromptTemplate();
    prompt.setPromptKey(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    prompt.setContent("지시문");
    Context context = new Context();
    context.setVariable("prompts", List.of(prompt));
    // _csrf 를 넣지 않는다 — 골격이 meta 를 내보내지 않는 상황
    return engine.process("admin/prompts", context);
  }

  /** 화면 스크립트 본문 (프롬프트 버튼 처리기가 든 것). */
  private String promptScript(String html) {
    Matcher matcher = Pattern.compile("(?s)<script[^>]*>(.*?)</script>").matcher(html);
    while (matcher.find()) {
      if (matcher.group(1).contains("preview-btn")) {
        return matcher.group(1);
      }
    }
    throw new AssertionError("프롬프트 화면 스크립트를 찾지 못했다");
  }

  @Test
  @DisplayName("meta 가 없어도 첫 줄에서 멈추지 않는다 — meta 의 content 를 바로 읽지 않는다")
  void script_doesNotDereferenceMissingMeta() {
    String html = render();

    assertThat(html).doesNotContain("<meta name=\"_csrf\"");
    String script = promptScript(html);
    // querySelector(...) 결과에 곧바로 .content 를 붙이면 null 에서 예외가 나 스크립트 전체가 멈춘다
    assertThat(script).doesNotContainPattern("querySelector\\([^)]*_csrf[^)]*\\)\\s*\\.content");
  }

  @Test
  @DisplayName("토큰이 없으면 요청 때 새로고침 안내와 에러 코드를 보인다")
  void script_explainsMissingToken() {
    String script = promptScript(render());

    assertThat(script).contains("보안 토큰을 찾지 못했어요").contains("새로고침해 주세요").contains("E-PRM-CSRF");
  }
}
