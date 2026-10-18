package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import java.util.Map;
import org.springframework.context.support.GenericApplicationContext;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.spring6.expression.ThymeleafEvaluationContext;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 스프링 없이 관리자 템플릿을 그리는 시험 도구: 컨텍스트 경로 없음, ${@adminDate} 빈 제공
 * 공통 조각(lastChanged 등)이 날짜 포맷 빈을 쓰므로 목록 화면 시험이 함께 쓴다
 */
final class AdminTemplateRenderSupport {

  private final SpringTemplateEngine engine;
  private final GenericApplicationContext applicationContext;

  AdminTemplateRenderSupport() {
    ClassLoaderTemplateResolver resolver = new ClassLoaderTemplateResolver();
    resolver.setPrefix("templates/");
    resolver.setSuffix(".html");
    resolver.setTemplateMode(TemplateMode.HTML);
    resolver.setCharacterEncoding("UTF-8");
    engine = new SpringTemplateEngine();
    engine.setTemplateResolver(resolver);
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
    applicationContext = new GenericApplicationContext();
    applicationContext.registerBean("adminDate", AdminDateFormatter.class);
    applicationContext.refresh();
  }

  String render(String template, Map<String, Object> variables) {
    Context context = new Context();
    context.setVariables(variables);
    return render(template, context);
  }

  /// 이미 변수를 담은 Context 로 그린다 (${@adminDate} 빈 제공)
  String render(String template, Context context) {
    context.setVariable(ThymeleafEvaluationContext.THYMELEAF_EVALUATION_CONTEXT_CONTEXT_VARIABLE_NAME,
      new ThymeleafEvaluationContext(applicationContext, null));
    return engine.process(template, context);
  }
}
