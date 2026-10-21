package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberCreditSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSubscriptionHistoryLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSubscriptionSummary;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter;
import com.chuseok22.elumserver.admin.application.list.AdminFeedbackList;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminListRow;
import com.chuseok22.elumserver.admin.application.list.AdminMemberList;
import com.chuseok22.elumserver.admin.application.list.AdminRoutineList;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionHistoryAction;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
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
  @DisplayName("필터 바: 날짜·글자 필터는 입력 칸으로, 적용된 조건은 x 링크 칩과 필터 초기화로, CSV 는 상한을 넘으면 막힌다")
  void filterBar_rendersInputsChipsAndCsvLimit() {
    AdminListDefinition definition = new AdminListDefinition(DEFINITION.columns(), List.of("name"),
      List.of(DEFINITION.filters().get(0), Filter.date("from", "시작일"), Filter.text("guardian", "보호자")),
      "name,asc");
    AdminListQuery query = AdminListQuery.of("하늘", Map.of("status", "ACTIVE", "from", "2026-10-01"), null, null,
      definition);
    java.util.Map<String, Object> model = new java.util.HashMap<>();
    model.put("definition", definition);
    model.put("query", query);
    model.put("page", pageOf(1, 0));
    model.put("rows", List.<AdminListRow>of());
    model.put("csvExport", AdminCsvExporter.linkOf("/admin/test", query, AdminCsvExporter.MAX_ROWS + 1L));

    String html = engine.process("test/admin-list-smoke", contextWith(model));

    // 입력 칸: 날짜 필터는 값이 채워진 date, 글자 필터는 text. 입력 칸 필터는 숨은 값으로 겹쳐 싣지 않는다
    assertThat(html).containsPattern("type=\"date\" name=\"from\"\\s+value=\"2026-10-01\"")
      .containsPattern("type=\"text\" name=\"guardian\"");
    assertThat(html).doesNotContainPattern("type=\"hidden\"\\s+name=\"from\"")
      .containsPattern("type=\"hidden\"\\s+name=\"status\" value=\"ACTIVE\"");
    // 칩: 선택지 이름으로 보이고 x 링크는 그 조건만 뺀다. 초기화는 정렬만 남긴다
    assertThat(html).contains("data-admin-active-filters").contains("상태: 활성").contains("시작일: 2026-10-01")
      .contains("href=\"?q=%ED%95%98%EB%8A%98&amp;from=2026-10-01&amp;sort=name,asc\"")
      .contains("href=\"?sort=name,asc\"").contains("필터 초기화");
    // CSV: 상한을 넘으면 링크 대신 막힌 버튼과 이유
    assertThat(html).contains("data-admin-csv-export").contains("disabled").contains("10,000건 이하로 좁히면")
      .doesNotContain("href=\"/admin/test/export.csv");
  }

  @Test
  @DisplayName("표는 첫 칸 외에 cellLinks 로 지정한 칸도 링크로 그린다")
  void table_rendersCellLinks() {
    AdminListQuery query = AdminListQuery.of(null, null, null, null, DEFINITION);
    String html = engine.process("test/admin-list-smoke", contextWith(Map.of(
      "definition", DEFINITION, "query", query, "page", pageOf(1, 0),
      "rows", List.of(new AdminListRow("/admin/x/1", Map.of("name", "하늘", "memo", "메모"), Map.of("memo", "/admin/members/m1"))))));

    assertThat(html).contains("href=\"/admin/x/1\"").contains("href=\"/admin/members/m1\"");
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
    AdminListQuery routineQuery = AdminListQuery.of("아침", Map.of("status", "CONFIRMED"), null, null,
      AdminRoutineList.DEFINITION);
    java.util.Map<String, Object> routineModel = new java.util.HashMap<>();
    routineModel.put("routines", pageOf(100, 1));
    routineModel.put("definition", AdminRoutineList.DEFINITION);
    routineModel.put("query", routineQuery);
    routineModel.put("rows", List.of());
    routineModel.put("pagerBaseUrl", "/admin/routines" + routineQuery.toQueryString(routineQuery.sort(), 1));
    String routines = engine.process("admin/routines", contextWith(routineModel));
    assertThat(routines).contains("data-admin-pager").contains("2 / 5")
      .contains("href=\"/admin/routines?q=%EC%95%84%EC%B9%A8&amp;status=CONFIRMED&amp;sort=updatedAt,desc&amp;page=1\"")
      .contains("page=3");

    AdminListQuery feedbackQuery = AdminListQuery.of(null, Map.of(), null, null, AdminFeedbackList.DEFINITION);
    java.util.Map<String, Object> feedbackModel = new java.util.HashMap<>();
    feedbackModel.put("feedbacks", pageOf(100, 0));
    feedbackModel.put("definition", AdminFeedbackList.DEFINITION);
    feedbackModel.put("query", feedbackQuery);
    feedbackModel.put("statuses", com.chuseok22.elumserver.feedback.core.FeedbackStatus.values());
    feedbackModel.put("pagerBaseUrl", "/admin/feedback" + feedbackQuery.toQueryString(feedbackQuery.sort(), 1));
    String feedbacks = engine.process("admin/feedback", contextWith(feedbackModel));
    assertThat(feedbacks).contains("data-admin-pager").contains("href=\"/admin/feedback?sort=createdAt,desc&amp;page=2\"");

    java.util.Map<String, Object> memberModel = new java.util.HashMap<>();
    memberModel.put("members", pageOf(100, 1));
    AdminListQuery memberQuery = AdminListQuery.of(null, Map.of(), null, null, AdminMemberList.DEFINITION);
    memberModel.put("definition", AdminMemberList.DEFINITION);
    memberModel.put("query", memberQuery);
    memberModel.put("rows", List.of());
    memberModel.put("pagerBaseUrl", "/admin/members" + memberQuery.toQueryString(memberQuery.sort(), 1));
    String members = engine.process("admin/members", contextWith(memberModel));
    assertThat(members).contains("data-admin-pager").contains("2 / 5").contains("page=1").contains("page=3");
  }

  private static AdminMemberResponse memberRow(PlanType plan, LocalDateTime changedAt, String changedBy) {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    member.setStatus(MemberStatus.ACTIVE);
    Subscription subscription = new Subscription();
    subscription.setPlan(plan);
    subscription.setExpiresAt(plan == PlanType.PRO ? LocalDateTime.of(2026, 12, 1, 0, 0) : null);
    SubscriptionHistory change = null;
    if (changedAt != null) {
      change = new SubscriptionHistory();
      change.setChangedAt(changedAt);
      change.setChangedBy(changedBy);
    }
    return AdminMemberResponse.of(member, null, 2, null, null, subscription, change);
  }

  @Test
  @DisplayName("회원 목록: 요금제 열·필터 칩·정렬 링크·마지막 변경이 그려지고 이력 없는 회원은 안내가 나온다")
  void memberList_showsPlanColumnFilterAndLastChanged() {
    AdminListQuery query = AdminListQuery.of(null, Map.of("plan", "PRO"), "plan,desc", null, AdminMemberList.DEFINITION);
    AdminDateFormatter dateFormatter = new AdminDateFormatter();
    java.util.Map<String, Object> model = new java.util.HashMap<>();
    model.put("members", pageOf(2, 0));
    model.put("definition", AdminMemberList.DEFINITION);
    model.put("query", query);
    model.put("rows", List.of(
      AdminMemberList.toRow(memberRow(PlanType.PRO, LocalDateTime.of(2026, 10, 18, 9, 5), "admin1"), dateFormatter),
      AdminMemberList.toRow(memberRow(PlanType.FREE, null, null), dateFormatter)));
    model.put("pagerBaseUrl", "/admin/members");

    String html = engine.process("admin/members", contextWith(model));

    assertThat(html).contains("요금제").contains("프로 (~2026-12-01 00:00)").contains("2026-10-18 09:05 · admin1");
    assertThat(html).contains("변경 이력 없음");
    // 요금제 필터 칩: 선택된 PRO 는 활성이고 전체 칩은 필터를 해제한다
    assertThat(html).contains("aria-label=\"요금제\"").contains("plan=PRO");
    // 요금제 열 헤더는 정렬 링크 (현재 내림차순이라 다음은 오름차순)
    assertThat(html).contains("요금제 ▼").contains("sort=plan,asc");
  }

  @Test
  @DisplayName("회원 상세: 부여 폼은 사유(reason)를 받고 Pro 일 때만 회수 폼이 나오며 이력 표에 전후 요금제·변경자·사유가 보인다")
  void memberDetail_showsGrantRevokeFormsAndHistory() {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    member.setStatus(MemberStatus.ACTIVE);
    Subscription proSubscription = new Subscription();
    proSubscription.setPlan(PlanType.PRO);
    List<AdminSubscriptionHistoryLine> history = List.of(
      new AdminSubscriptionHistoryLine(LocalDateTime.of(2026, 10, 18, 9, 5), "admin1", SubscriptionHistoryAction.GRANT,
        PlanType.FREE, PlanType.PRO, 30, LocalDateTime.of(2026, 11, 17, 9, 5), "베타 <테스터>"),
      new AdminSubscriptionHistoryLine(LocalDateTime.of(2026, 10, 19, 9, 5), "admin2", SubscriptionHistoryAction.REVOKE,
        PlanType.PRO, PlanType.FREE, null, null, "기간 오입력"));

    String html = engine.process("admin/member-detail", contextWith(Map.of("member",
      AdminMemberDetailResponse.of(member, null, List.of(), null, List.of(),
        AdminSubscriptionSummary.from(proSubscription), history, null))));

    assertThat(html).contains("data-grant-pro-form").contains("name=\"reason\"").doesNotContain("name=\"memo\"");
    assertThat(html).contains("data-revoke-pro-form");
    assertThat(html).contains("data-plan-history").contains("무료 → 프로").contains("프로 → 무료")
      .contains("30일 (~2026-11-17 09:05)").contains("admin2").contains("기간 오입력");
    assertThat(html).as("사유는 이스케이프된다").contains("베타 &lt;테스터&gt;").doesNotContain("<테스터>");
    // 마지막 변경은 이력의 가장 앞(최신) 한 줄
    assertThat(html).contains("마지막 변경").contains("data-last-changed").contains("· admin1");

    String freeHtml = engine.process("admin/member-detail", contextWith(Map.of("member",
      AdminMemberDetailResponse.of(member, null, List.of(), null, List.of(),
        AdminSubscriptionSummary.none(), List.of(), null))));
    assertThat(freeHtml).doesNotContain("data-revoke-pro-form").contains("아직 요금제를 바꾼 기록이 없어요")
      .contains("변경 이력 없음");
  }

  @Test
  @DisplayName("회원 상세 크레딧 요약 카드: 잔액·동결이 그려지고, 조회 실패면 안내와 에러 코드만 나온다 (#651)")
  void memberDetail_rendersCreditSummaryStates() {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    member.setStatus(MemberStatus.ACTIVE);
    AdminMemberDetailResponse detail = AdminMemberDetailResponse.of(member, null, List.of(), null, List.of(),
      AdminSubscriptionSummary.none(), List.of(), null);

    String loadedHtml = engine.process("admin/member-detail", contextWith(Map.of("member", detail,
      "creditSummary", new AdminMemberCreditSummary(false, true, 1234, 300, 50, 120, true))));
    assertThat(loadedHtml).contains("data-member-credit-summary").contains("1,234").contains("동결")
      .contains("data-member-actions-menu").contains("크레딧 지급");

    String failedHtml = engine.process("admin/member-detail", contextWith(Map.of("member", detail,
      "creditSummary", AdminMemberCreditSummary.loadFailed())));
    assertThat(failedHtml).contains("크레딧 정보를 불러오지 못했어요").contains("E-ADM-CREDIT-001")
      .doesNotContain("아직 크레딧 기록이 없어요");
  }

  @Test
  @DisplayName("회원 상세: 공통 확인창이 한 번 그려지고 위험 동작은 data-confirm 으로 거치며, 완전 삭제는 이름 입력을 요구한다 (#657)")
  void memberDetail_routesDangerousActionsThroughSharedConfirmDialog() {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    member.setStatus(MemberStatus.ACTIVE);
    String activeHtml = engine.process("admin/member-detail", contextWith(Map.of("member",
      AdminMemberDetailResponse.of(member, null, List.of(), null, List.of(),
        AdminSubscriptionSummary.none(), List.of(), null))));

    // 확인창 조각은 레이아웃이 한 번만 넣는다 (두 번이면 스크립트가 다른 dialog 를 붙잡는다)
    assertThat(activeHtml.split("<dialog", -1)).hasSize(2);
    assertThat(activeHtml).contains("window.ElumAdminConfirm").doesNotContain("onsubmit=");
    assertThat(activeHtml).containsPattern("/suspend\"[^>]*data-confirm-danger[^>]*data-confirm-message=\"이 계정을 정지할까요?");
    // 이 회원의 기록: 각 화면이 받는 필터 이름으로 회원 id 를 싣는다
    assertThat(activeHtml).contains("href=\"/admin/feedback?q=m1\"").contains("href=\"/admin/routines?guardian=m1\"")
      .contains("href=\"/admin/monitoring?memberId=m1\"").contains("href=\"/admin/credits/members/m1#ledger\"");

    member.setStatus(MemberStatus.WITHDRAWN);
    String withdrawnHtml = engine.process("admin/member-detail", contextWith(Map.of("member",
      AdminMemberDetailResponse.of(member, null, List.of(), null, List.of(),
        AdminSubscriptionSummary.none(), List.of(), null))));
    assertThat(withdrawnHtml).containsPattern("/purge\"[^>]*data-confirm-typed-name=\"parent1\"");
  }
}
