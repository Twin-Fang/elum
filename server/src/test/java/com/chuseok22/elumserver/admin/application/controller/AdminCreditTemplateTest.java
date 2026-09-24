package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustForm;
import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustType;
import com.chuseok22.elumserver.admin.application.dto.request.CreditPolicyForm;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditJobRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditMemberDetail;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditOverview;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditWeekRow;
import com.chuseok22.elumserver.admin.application.dto.response.CreditAdjustPreview;
import com.chuseok22.elumserver.admin.application.dto.response.CreditPolicyPreview;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService.JobFilter;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService.MemberFilter;
import com.chuseok22.elumserver.credit.application.service.CreditBalance;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.license.core.PlanType;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * AI 크레딧 관리자 화면 다섯 개가 실제로 그려지는지 (#407).
 *
 * <p>식 하나가 틀리면(없는 메서드·null 접근) 그 화면은 500 이다. 컴파일로도 단위 테스트로도 안 잡혀 서버를
 * 띄우고 눌러 봐야 드러난다. 스프링 없이 템플릿 엔진만으로 빈 상태·값이 찬 상태를 둘 다 그려 본다
 * (AdminNoticeTemplateTest 와 같은 방식).
 */
class AdminCreditTemplateTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 23, 15, 0);
  private static final CreditPeriod PERIOD = CreditPeriod.of(NOW);

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
    // 웹 요청 없이 그리므로 @{/...} 링크에 붙일 컨텍스트 경로가 없다. 빈 값으로 둔다.
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
  }

  private String render(String template, Map<String, Object> variables) {
    Context context = new Context();
    context.setVariables(variables);
    return engine.process(template, context);
  }

  private static AiCreditPolicy policy(boolean enabled) {
    AiCreditPolicy policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(3);
    policy.setEnabled(enabled);
    policy.setEffectiveFrom(NOW.minusDays(1));
    policy.setWeeklyGrantJson("{\"FREE\":100,\"PRO\":120}");
    policy.setActionCostsJson("{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":2,\"IMAGE_REGENERATE\":1}");
    policy.setCreatedBy("admin1");
    policy.setReason("비공개 테스트 시작");
    return policy;
  }

  private static AiCreditJob job(String id, CreditJobStatus status, int charged, int overage) {
    AiCreditJob job = new AiCreditJob();
    job.setId(id);
    job.setAccountId("acc1");
    job.setRequestKey("req-" + id);
    job.setKind(CreditJobKind.ROUTINE_CREATE);
    job.setStatus(status);
    job.setReserved(1);
    job.setCharged(charged);
    job.setOverage(overage);
    job.setCardCount(5);
    job.setImageCount(4);
    job.setStartedAt(NOW.minusMinutes(30));
    job.setFailReason(status == CreditJobStatus.RELEASED ? "AI 실패" : null);
    return job;
  }

  private static List<AdminCreditJobRow> jobRows() {
    return List.of(
      new AdminCreditJobRow(job("j1", CreditJobStatus.SETTLED, 5, 0), "m1", "kimchi", 6, 0.0123, false),
      new AdminCreditJobRow(job("j2", CreditJobStatus.SETTLED, 1, 8), "m1", "kimchi", 0, 0, false),
      new AdminCreditJobRow(job("j3", CreditJobStatus.RESERVED, 0, 0), "m1", null, 0, 0, true),
      new AdminCreditJobRow(job("j4", CreditJobStatus.RELEASED, 0, 0), null, null, 1, 0.001, false));
  }

  // --- 개요 ---

  private AdminCreditOverview overview(boolean enabled, long used, Double perCredit, long stuck, long mismatch,
    List<AdminCreditOverview.ModelCost> models, List<AdminCreditOverview.KindCost> kinds, boolean current) {
    return new AdminCreditOverview(PERIOD, "2026-W38", current ? null : "2026-W40", current, 12, 1200, 30, used, 2,
      900, 1, 8, 3, 2, 1.23, 0.5, perCredit, models, kinds, stuck, mismatch, true, policy(enabled));
  }

  @Test
  @DisplayName("개요 — 숫자·모델별 USD·작업 종류 평균·경고 넷을 그린다")
  void overview_full() {
    String html = render("admin/credits", Map.of("overview", overview(false, 300, 0.0041, 2, 3,
      List.of(new AdminCreditOverview.ModelCost("gemini-2.5-flash", 40, 1.2)),
      List.of(new AdminCreditOverview.KindCost(CreditJobKind.ROUTINE_CREATE, 10, 25, 0.5)), true)));

    assertThat(html).contains("AI 크레딧").contains("2026-W39").contains("이번 주")
      .contains("gemini-2.5-flash").contains("$0.0041").contains("ROUTINE_CREATE").contains("2.5")
      .contains("크레딧 정책이 꺼져 있어요").contains("비용 상한").contains("멈춘 예약").contains("대조 불일치")
      .contains("/admin/credits/jobs?mismatch=true&amp;from=2026-09-21&amp;to=2026-09-27")
      .contains("/admin/credits?week=2026-W38");
    // 사이드 메뉴에 AI 크레딧이 켜져 있다
    assertThat(html).containsPattern("href=\"/admin/credits\"[^>]*class=\"[^\"]*active");
    assertThat(html).doesNotContain("다음 주 →");
  }

  @Test
  @DisplayName("개요 — 사용 0 이면 크레딧당 원가는 — , 호출·작업이 없으면 빈 줄")
  void overview_empty() {
    String html = render("admin/credits", Map.of("overview",
      overview(true, 0, null, 0, 0, List.of(), List.of(), false)));

    assertThat(html).contains("—").contains("그 주 AI 호출이 없어요").contains("그 주 정산한 작업이 없어요")
      .contains("다음 주 →").doesNotContain("멈춘 예약 <b>");
  }

  // --- 회원별 ---

  private static AdminCreditWeekRow row(String accountId, String memberId, boolean frozen, Integer weekly, long remaining,
    long overage) {
    return new AdminCreditWeekRow(accountId, memberId, memberId == null ? null : "user-" + memberId,
      memberId == null ? null : "하늘이", memberId == null ? null : PlanType.FREE, frozen, weekly, 10, 40, 1,
      remaining, overage, overage > 0 ? 1 : 0, NOW.minusHours(3));
  }

  @Test
  @DisplayName("회원별 — 소진·동결·떼어진 계정·초과를 표시하고 페이지 링크에 필터를 싣는다")
  void members_rows() {
    List<AdminCreditWeekRow> rows = List.of(
      row("acc1", "m1", false, 100, 0, 8),
      row("acc2", "m2", true, 100, 30, 0),
      row("acc3", null, false, null, 0, 0));
    Page<AdminCreditWeekRow> page = new PageImpl<>(rows, PageRequest.of(1, 20), 45);

    String html = render("admin/credits-members", Map.of(
      "period", PERIOD, "rows", page, "filter", new MemberFilter("하늘", true, false, false),
      "keyword", "하늘", "sort", "OVERAGE_DESC"));

    assertThat(html).contains("하늘이").contains("user-m1").contains("떼어진 계정").contains("소진").contains("동결")
      .contains("8 (1건)").contains("/admin/credits/members/m1").contains("총 <span>45</span>개 계정")
      .contains("page=0").contains("exhausted=true");
  }

  @Test
  @DisplayName("회원별 — 0건이면 빈 줄")
  void members_empty() {
    String html = render("admin/credits-members", Map.of(
      "period", PERIOD, "rows", Page.empty(PageRequest.of(0, 20)),
      "filter", new MemberFilter(null, false, false, false), "keyword", "", "sort", "USED_DESC"));

    assertThat(html).contains("조건에 맞는 계정이 없어요");
  }

  // --- 회원 상세 ---

  private static AdminCreditMemberDetail detail(boolean withAccount) {
    AiCreditAccount account = new AiCreditAccount();
    account.setId("acc1");
    account.setMemberId("m1");
    account.setStatus(CreditAccountStatus.FROZEN);
    AiCreditGrant weekly = new AiCreditGrant();
    weekly.setSource(CreditGrantSource.WEEKLY);
    weekly.setAmount(100);
    weekly.setRemaining(12);
    weekly.setValidFrom(PERIOD.start());
    weekly.setExpiresAt(PERIOD.end());
    weekly.setPeriodKey(PERIOD.key());
    AiCreditGrant bonus = new AiCreditGrant();
    bonus.setSource(CreditGrantSource.ADMIN_BONUS);
    bonus.setAmount(30);
    bonus.setRemaining(30);
    bonus.setValidFrom(NOW);
    bonus.setRefId("admin:admin1");
    AiCreditLedger line = new AiCreditLedger();
    line.setType(CreditLedgerType.ADJUST);
    line.setDelta(30);
    line.setBalanceAfter(42);
    line.setActor("admin1");
    line.setReason("[지급] 시연 보상");
    AiCreditLedger consume = new AiCreditLedger();
    consume.setType(CreditLedgerType.CONSUME);
    consume.setDelta(-5);
    consume.setBalanceAfter(37);
    if (!withAccount) {
      return new AdminCreditMemberDetail("m1", "kimchi", null, PlanType.FREE, null, null, List.of(),
        Page.empty(PageRequest.of(0, 20)), Page.empty(PageRequest.of(0, 20)), null, policy(true));
    }
    return new AdminCreditMemberDetail("m1", "kimchi", "하늘이", PlanType.PRO, account,
      new CreditBalance(42, 100, 30, 88, 1, PERIOD), List.of(weekly, bonus),
      new PageImpl<>(jobRows(), PageRequest.of(0, 20), 45), new PageImpl<>(List.of(line, consume)),
      CreditLedgerType.ADJUST, policy(true));
  }

  private static CreditAdjustForm blankForm() {
    return new CreditAdjustForm("GRANT", "", "WEEK_END", "", "");
  }

  @Test
  @DisplayName("회원 상세 — 잔액·묶음·작업(불일치·멈춤·반환 폼)·원장·조정 폼을 그린다")
  void memberDetail_full() {
    String html = render("admin/credits-member-detail", Map.of(
      "detail", detail(true), "form", blankForm(),
      "ledgerTypes", CreditLedgerType.values(), "adjustTypes", CreditAdjustType.values(),
      "message", "지급 반영했어요."));

    assertThat(html).contains("하늘이").contains("프로").contains("동결").contains("42").contains("관리자 보너스")
      .contains("12 / 100").contains("무기한").contains("호출 기록 없음").contains("멈춤")
      .contains("/admin/credits/jobs/j3/release").contains("value=\"/admin/credits/members/m1\"")
      .contains("+30").contains("[지급] 시연 보상").contains("action=\"/admin/credits/members/m1/adjust/preview\"")
      .contains("name=\"expiryMode\"").contains("지급 반영했어요.").contains("jobPage=1")
      .contains("/admin/members/m1");
    // 반환 폼은 RESERVED 인 줄에만 있다
    assertThat(html.split("/release\"", -1)).hasSize(2);
    assertThat(html).doesNotContain("이대로 반영");
  }

  @Test
  @DisplayName("회원 상세 — 계정이 없으면 빈 화면 안내, 조정 폼은 남는다")
  void memberDetail_noAccount() {
    String html = render("admin/credits-member-detail", Map.of(
      "detail", detail(false), "form", blankForm(),
      "ledgerTypes", CreditLedgerType.values(), "adjustTypes", CreditAdjustType.values()));

    assertThat(html).contains("아직 크레딧 계정이 없어요").contains("미리보기").doesNotContain("원장에 기록이 없어요");
  }

  @Test
  @DisplayName("회원 상세 — 미리보기면 확인 상자와 같은 값을 실은 반영 폼을 그린다")
  void memberDetail_preview() {
    CreditAdjustForm form = new CreditAdjustForm("GRANT", "30", "DATE", "2026-10-01", "시연 보상");
    CreditAdjustPreview preview = new CreditAdjustPreview(CreditAdjustType.GRANT, 30, 12, 42,
      LocalDateTime.of(2026, 10, 2, 0, 0), false, false);

    String html = render("admin/credits-member-detail", Map.of(
      "detail", detail(true), "form", form, "preview", preview,
      "ledgerTypes", CreditLedgerType.values(), "adjustTypes", CreditAdjustType.values(),
      "errorMessage", "조정할 수 없어요: 예시 (E-CRD-001)"));

    assertThat(html).contains("남음 12 → 42, 즉시 적용").contains("만료: 2026-10-02 00:00").contains("사유: 시연 보상")
      .contains("action=\"/admin/credits/members/m1/adjust\"").contains("name=\"amount\" value=\"30\"")
      .contains("name=\"expiryDate\" value=\"2026-10-01\"").contains("이대로 반영").contains("E-CRD-001");
  }

  // --- 정책 ---

  private static CreditPolicyPreview policyPreview(boolean disabling, Double perCredit) {
    return new CreditPolicyPreview(null, 20, 18, 2, 2040, 3000, 3.5, 1.25, perCredit,
      perCredit == null ? null : 4.2, perCredit == null ? null : 5.1, true, 12, 600, disabling, 2, -1);
  }

  @Test
  @DisplayName("정책 — 지금 정책 카드·발행 폼·이력을 그린다")
  void policy_page() {
    AiCreditPolicy current = policy(true);
    String html = render("admin/credits-policy", Map.of(
      "current", current, "currentValues", CreditPolicyForm.of(current), "form", CreditPolicyForm.of(current),
      "history", List.of(current)));

    assertThat(html).contains("지금 정책 v").contains("100 / 120").contains("1 / 2 / 1").contains("15분")
      .contains("action=\"/admin/credits/policy/preview\"").contains("name=\"freeGrant\"")
      .contains("{&quot;FREE&quot;:100,&quot;PRO&quot;:120}").contains("비공개 테스트 시작")
      .doesNotContain("영향 미리보기</h2>");
  }

  @Test
  @DisplayName("정책 — 끄는 미리보기는 옛 횟수 한도와 끄고 발행 확인을 보인다")
  void policy_disablingPreview() {
    AiCreditPolicy current = policy(true);
    CreditPolicyForm form = new CreditPolicyForm("100", "120", "1", "1", "1", "15", null, "NEXT_PERIOD", "비용 점검");
    String html = render("admin/credits-policy", Map.of(
      "current", current, "currentValues", CreditPolicyForm.of(current), "form", form,
      "history", List.of(current), "preview", policyPreview(true, 0.004)));

    assertThat(html).contains("영향 미리보기").contains("2040 → 3000 (+960)").contains("3.5 → 1.2")
      .contains("하루 <b>2개</b>").contains("주당 <b>무제한</b>").contains("끄고 발행")
      .contains("data-confirm=\"크레딧을 끌까요?").contains("name=\"enabled\" value=\"false\"")
      .contains("이번 주 지급 12개 계정을 +600");
  }

  @Test
  @DisplayName("정책 — 지난 4주 사용이 없으면 원가·예상 USD 는 — , 폼 오류를 보인다")
  void policy_previewWithoutUsage() {
    AiCreditPolicy current = AiCreditPolicy.disabledDefault();
    String html = render("admin/credits-policy", Map.of(
      "current", current, "currentValues", CreditPolicyForm.of(current), "form", CreditPolicyForm.of(current),
      "history", List.of(), "preview", policyPreview(false, null),
      "errorMessage", "미리볼 수 없어요: 사유 (E-CRD-003)"));

    assertThat(html).contains("지난 4주 사용 없음").contains("발행한 정책이 없어요").contains("꺼진 기본값")
      .contains("이대로 발행").contains("E-CRD-003");
  }

  // --- 작업 탐색 ---

  @Test
  @DisplayName("작업 탐색 — 필터 값을 되살리고 줄마다 대조·반환을 그린다")
  void jobs_page() {
    JobFilter filter = new JobFilter(CreditJobStatus.SETTLED, CreditJobKind.ROUTINE_CREATE,
      LocalDate.of(2026, 9, 21), LocalDate.of(2026, 9, 27), true, true, "req");
    String html = render("admin/credits-jobs", Map.of(
      "rows", new PageImpl<>(jobRows(), PageRequest.of(0, 20), 45), "filter", filter,
      "statuses", CreditJobStatus.values(), "kinds", CreditJobKind.values(), "q", "req"));

    assertThat(html).contains("kimchi").contains("호출 기록 없음").contains("멈춤").contains("5 / 4")
      .contains("$0.0123").contains("value=\"2026-09-21\"").contains("/admin/credits/jobs/j3/release")
      .contains("mismatch=true").contains("AI 실패");
  }

  @Test
  @DisplayName("작업 탐색 — 0건이면 빈 줄")
  void jobs_empty() {
    String html = render("admin/credits-jobs", Map.of(
      "rows", Page.empty(PageRequest.of(0, 20)),
      "filter", new JobFilter(null, null, null, null, false, false, null),
      "statuses", CreditJobStatus.values(), "kinds", CreditJobKind.values(), "q", ""));

    assertThat(html).contains("조건에 맞는 작업이 없어요");
  }
}
