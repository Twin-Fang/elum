package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminListRow;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.GenericApplicationContext;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.spring6.expression.ThymeleafEvaluationContext;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 공통 목록 조각(pager, filterBar, table, lastChanged)이 그려지고, 이를 쓰는 기존 화면 3개(회원·일과·의견)가 깨지지 않는지 본다.
 * 스프링 컨텍스트 없이 템플릿 엔진만으로 그린다.
 */
class AdminFragmentRenderTest {

  private static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(new Column("name", "이름", true), new Column("memo", "메모", false)),
    List.of("name"),
    List.of(new Filter("status", "상태", List.of(new Option("ACTIVE", "활성"), new Option("WITHDRAWN", "탈퇴")))),
    "name,asc");

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

  private Context contextWith(Map<String, Object> variables) {
    Context context = new Context();
    context.setVariables(variables);
    context.setVariable(ThymeleafEvaluationContext.THYMELEAF_EVALUATION_CONTEXT_CONTEXT_VARIABLE_NAME,
      new ThymeleafEvaluationContext(applicationContext, null));
    return context;
  }

  private static PageImpl<Object> pageOf(int totalElements, int pageIndex) {
    return new PageImpl<>(List.of(), PageRequest.of(pageIndex, 20), totalElements);
  }

  @Test
  @DisplayName("공통 조각: 필터 칩·정렬 헤더·페이저·마지막 변경이 조건을 유지한 링크로 그려진다")
  void sharedFragments_render() {
    AdminListQuery query = AdminListQuery.of("a&b", Map.of("status", "ACTIVE"), "name,asc", "2", DEFINITION);
    String html = engine.process("test/admin-list-smoke", contextWith(Map.of(
      "definition", DEFINITION, "query", query, "page", pageOf(100, 1),
      "rows", List.of(new AdminListRow("/admin/x/1", Map.of("name", "<b>하늘</b>", "memo", "메모"))),
      "changedAt", LocalDateTime.of(2026, 10, 18, 9, 5, 30), "changedBy", "admin")));

    assertThat(html).contains("data-admin-filter-bar").contains("data-admin-pager").contains("data-last-changed");
    // 필터 칩: 현재 선택은 활성, 다른 칩 링크는 q 를 유지하고 페이지를 1로 되돌린다
    assertThat(html).contains("btn btn-sm join-item btn-primary");
    assertThat(html).contains("href=\"?q=a%26b&amp;status=WITHDRAWN&amp;sort=name,asc\"");
    // 정렬 헤더: 현재 정렬 열은 방향 표시, 반대 방향 링크
    assertThat(html).contains("이름 ▲").contains("sort=name,desc");
    assertThat(html).as("정렬 불가 열은 링크가 아니다").doesNotContain(">메모</a>");
    // 행: 첫 칸 링크, 값은 이스케이프
    assertThat(html).contains("href=\"/admin/x/1\"").contains("&lt;b&gt;하늘&lt;/b&gt;").doesNotContain("<b>하늘</b>");
    // 페이저: 2페이지 → 이전은 1, 다음은 3, 검색어는 인코딩돼 유지
    assertThat(html).contains("2 / 5").contains("href=\"/admin/test?q=a%26b&amp;page=1\"")
      .contains("href=\"/admin/test?q=a%26b&amp;page=3\"");
    // 마지막 변경
    assertThat(html).contains("2026-10-18 09:05").contains("· admin").contains("변경 이력 없음");
  }

  @Test
  @DisplayName("결과가 없으면 표는 빈 상태 줄을, 한 페이지뿐이면 페이저는 아무것도 그리지 않는다")
  void emptyRows_andSinglePage() {
    AdminListQuery query = AdminListQuery.of(null, null, null, null, DEFINITION);
    String html = engine.process("test/admin-list-smoke", contextWith(Map.of(
      "definition", DEFINITION, "query", query, "page", pageOf(3, 0), "rows", List.<AdminListRow>of())));

    assertThat(html).contains("조건에 맞는 항목이 없어요").doesNotContain("data-admin-pager");
  }

  @Test
  @DisplayName("회원·일과·의견 목록은 공통 페이저를 쓰고 검색 조건을 링크에 유지한다")
  void existingScreens_usePagerFragment() {
    String routines = engine.process("admin/routines", contextWith(Map.of(
      "routines", pageOf(100, 1), "keyword", "아침")));
    assertThat(routines).contains("data-admin-pager").contains("2 / 5")
      .contains("href=\"/admin/routines?keyword=%EC%95%84%EC%B9%A8&amp;page=1\"")
      .contains("page=3");

    String feedbacks = engine.process("admin/feedback", contextWith(Map.of("feedbacks", pageOf(100, 0))));
    assertThat(feedbacks).contains("data-admin-pager").contains("href=\"/admin/feedback?page=2\"");

    java.util.Map<String, Object> memberModel = new java.util.HashMap<>();
    memberModel.put("members", pageOf(100, 1));
    memberModel.put("keyword", "");
    memberModel.put("selectedStatus", null);
    String members = engine.process("admin/members", contextWith(memberModel));
    assertThat(members).contains("data-admin-pager").contains("2 / 5").contains("page=1").contains("page=3");
  }
}
