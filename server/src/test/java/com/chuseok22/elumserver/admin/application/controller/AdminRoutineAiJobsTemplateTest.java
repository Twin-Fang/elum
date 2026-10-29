package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineAiJobs;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineAiJobs.JobLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineDetailResponse;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.service.AdminRoutineAiJobService;
import com.chuseok22.elumserver.admin.application.service.AdminRoutineService;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.GenericApplicationContext;
import org.springframework.ui.ExtendedModelMap;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.spring6.expression.ThymeleafEvaluationContext;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/** 일과 상세 "이 일과의 AI 작업" 카드 (#652). 스프링 컨텍스트 없이 컨트롤러·템플릿 엔진만으로 본다. */
class AdminRoutineAiJobsTemplateTest {

  private SpringTemplateEngine engine;
  private GenericApplicationContext applicationContext;

  @BeforeEach
  void setUp() {
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
    // ${@adminDate...} 를 풀 빈 컨텍스트
    applicationContext = new GenericApplicationContext();
    applicationContext.registerBean("adminDate", AdminDateFormatter.class);
    applicationContext.refresh();
  }

  @Test
  @DisplayName("AI 작업 조회가 실패해도 일과 상세는 그려지고, 카드에 에러 코드가 보인다")
  void detail_aiJobsLoadFails_stillRendersWithErrorCode() {
    AdminRoutineService routineService = mock(AdminRoutineService.class);
    AdminRoutineAiJobService aiJobService = mock(AdminRoutineAiJobService.class);
    when(routineService.getDetail("r1")).thenReturn(AdminRoutineDetailResponse.from(routine(), "kimchi"));
    when(aiJobService.loadAiJobsOf("r1")).thenThrow(new IllegalStateException("db down"));
    AdminRoutineController controller =
      new AdminRoutineController(routineService, aiJobService, new AdminDateFormatter());
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.detail("r1", model);
    String html = engine.process(view, contextWith(model));

    assertThat(view).isEqualTo("admin/routine-detail");
    assertThat(html).contains("단계 목록").contains("data-routine-ai-jobs")
      .contains("AI 작업을 불러오지 못했어요").contains(AdminRoutineAiJobs.LOAD_FAILED_ERROR_CODE);
  }

  @Test
  @DisplayName("AI 작업 카드: 작업 링크·호출 성공/실패·합계 비용·실패 사유를 그리고, 0건이면 빈 상태 문구")
  void aiJobsCard_rendersJobsAndEmptyState() {
    JobLine settled = new JobLine("job-1", "일과 생성", "정산", LocalDateTime.of(2026, 10, 20, 9, 5),
      5, 5, 6, null, 6, 6, 0.012);
    JobLine released = new JobLine("job-2", "카드 그림", "반환", LocalDateTime.of(2026, 10, 20, 9, 30),
      1, 0, 0, "x".repeat(120), 2, 0, 0.0);
    String html = renderDetail(AdminRoutineAiJobs.of(List.of(settled, released), false));

    assertThat(html).contains("href=\"/admin/credits/jobs?q=job-1\"").contains("2026-10-20 09:05");
    // 합계: 호출 8건, 실패 2건, 비용 0.012
    assertThat(html).contains("호출 <b>8</b>건").containsPattern("실패 <b[^>]*>2</b>건").contains("$0.012000");
    // 실패 사유는 80자로 자르고 전체는 title
    assertThat(html).contains("x".repeat(77) + "...").contains("title=\"" + "x".repeat(120) + "\"");

    String empty = renderDetail(AdminRoutineAiJobs.of(List.of(), false));
    assertThat(empty).contains("이 일과로 만든 AI 작업이 없어요").contains("colspan=\"8\"");
  }

  private String renderDetail(AdminRoutineAiJobs aiJobs) {
    ExtendedModelMap model = new ExtendedModelMap();
    model.addAttribute("routine", AdminRoutineDetailResponse.from(routine(), "kimchi"));
    model.addAttribute("aiJobs", aiJobs);
    return engine.process("admin/routine-detail", contextWith(model));
  }

  private Context contextWith(Map<String, Object> variables) {
    Context context = new Context();
    context.setVariables(variables);
    context.setVariable(ThymeleafEvaluationContext.THYMELEAF_EVALUATION_CONTEXT_CONTEXT_VARIABLE_NAME,
      new ThymeleafEvaluationContext(applicationContext, null));
    return context;
  }

  private static Routine routine() {
    Profile profile = new Profile();
    profile.setId("p1");
    profile.setNickname("하늘이");
    Routine routine = new Routine();
    routine.setId("r1");
    routine.setProfile(profile);
    routine.setCreatedBy("member-1");
    routine.setTitle("아침 준비");
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("원문");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setScheduledAt(LocalDateTime.of(2026, 10, 20, 9, 0));
    routine.setSteps(List.of());
    routine.setLanguage(AppLocale.KO);
    return routine;
  }
}
