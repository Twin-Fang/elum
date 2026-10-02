package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
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
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/** 일과 목록·상세가 일과의 언어를 보이는지 (다국어 #526). 스프링 컨텍스트 없이 템플릿 엔진만으로 그린다. */
class AdminRoutineLanguageTemplateTest {

  private static final String BADGE = "badge badge-outline\"[^>]*>%s</span>";

  private SpringTemplateEngine engine;

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
  }

  private Routine routine(String id, String title, AppLocale language) {
    Profile profile = new Profile();
    profile.setId("p1");
    profile.setNickname("하늘이");
    Routine routine = new Routine();
    routine.setId(id);
    routine.setProfile(profile);
    routine.setCreatedBy("member-1");
    routine.setTitle(title);
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("원문");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setScheduledAt(LocalDateTime.of(2026, 10, 2, 9, 0));
    routine.setSteps(List.of());
    routine.setLanguage(language);
    return routine;
  }

  @Test
  @DisplayName("응답 DTO 는 일과의 언어 코드를 담는다")
  void dtos_carryLanguage() {
    assertThat(AdminRoutineResponse.from(routine("r1", "t", AppLocale.JA), "kimchi").language()).isEqualTo("ja");
    assertThat(AdminRoutineDetailResponse.from(routine("r1", "t", AppLocale.ES), "kimchi").language()).isEqualTo("es");
    assertThat(AdminRoutineResponse.from(routine("r1", "t", AppLocale.KO), "kimchi").language()).isEqualTo("ko");
  }

  @Test
  @DisplayName("언어가 null 인 옛 행도 NPE 없이 ko 로 떨어진다")
  void dtos_nullLanguage_fallsBackToKo() {
    Routine legacy = routine("r1", "t", null);

    assertThat(AdminRoutineResponse.from(legacy, "kimchi").language()).isEqualTo("ko");
    assertThat(AdminRoutineDetailResponse.from(legacy, "kimchi").language()).isEqualTo("ko");
  }

  @Test
  @DisplayName("목록은 언어 열을 보이고 일과마다 자기 언어를 보인다")
  void list_showsEachRoutinesLanguage() {
    Context context = new Context();
    context.setVariable("routines", new PageImpl<>(List.of(
      AdminRoutineResponse.from(routine("r1", "영어 일과", AppLocale.EN), "kimchi"),
      AdminRoutineResponse.from(routine("r2", "일본어 일과", AppLocale.JA), "kimchi")),
      PageRequest.of(0, 20), 2));
    context.setVariable("keyword", null);

    String html = engine.process("admin/routines", context);

    assertThat(html).contains("<th>언어</th>")
      .containsPattern(String.format(BADGE, "en"))
      .containsPattern(String.format(BADGE, "ja"))
      .doesNotContainPattern(String.format(BADGE, "ko"));
    // 행 순서대로 자기 언어가 붙는다
    assertThat(html.indexOf("영어 일과")).isLessThan(html.indexOf(">en</span>"));
    assertThat(html.indexOf(">en</span>")).isLessThan(html.indexOf("일본어 일과"));
    assertThat(html.indexOf("일본어 일과")).isLessThan(html.indexOf(">ja</span>"));
  }

  @Test
  @DisplayName("목록이 비면 빈 줄이 열 수(6)를 덮고 열 머리도 6개다")
  void list_empty_colspanCoversColumns() {
    Context context = new Context();
    context.setVariable("routines", new PageImpl<AdminRoutineResponse>(List.of(), PageRequest.of(0, 20), 0));
    context.setVariable("keyword", null);

    String html = engine.process("admin/routines", context);

    assertThat(html).contains("colspan=\"6\"");
    assertThat(html.split("<th>", -1).length - 1).isEqualTo(6);
  }

  @Test
  @DisplayName("상세는 일과마다 자기 콘텐츠 언어를 보인다")
  void detail_showsLanguage() {
    String zh = engine.process("admin/routine-detail", detailContext(AppLocale.ZH));
    String es = engine.process("admin/routine-detail", detailContext(AppLocale.ES));

    assertThat(zh).contains("콘텐츠 언어").containsPattern(String.format(BADGE, "zh"))
      .doesNotContainPattern(String.format(BADGE, "es"));
    assertThat(es).containsPattern(String.format(BADGE, "es")).doesNotContainPattern(String.format(BADGE, "zh"));
  }

  private Context detailContext(AppLocale language) {
    Context context = new Context();
    context.setVariable("routine", AdminRoutineDetailResponse.from(routine("r1", "t", language), "kimchi"));
    return context;
  }
}
