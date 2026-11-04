package com.chuseok22.elumserver.expertroutine;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineRepository;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineStepRepository;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.member.application.service.GuardianshipService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.jayway.jsonpath.JsonPath;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 실제 Postgres · 실제 보안 체인으로 하는 전문가 일과 가져오기 리허설 (#1076). 평소 빌드에서는 건너뛴다.
 * 목 테스트가 못 보는 것: 파생 쿼리(공개·검수·언어), 횟수 +1 쿼리, 일과 쪽 저장(카드·보상), 크레딧 표에 흔적 없음
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54776/elum ./gradlew test --tests '*ExpertRoutineImportRehearsalIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.flyway.enabled=false",
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=elum",
  "spring.datasource.password=pw",
  "spring.jpa.hibernate.ddl-auto=${ELUM_IT_DDL_AUTO:update}",
  "gemini.api-key=rehearsal-invalid"
})
@ActiveProfiles("dev")
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class ExpertRoutineImportRehearsalIT {

  @Autowired private MockMvc mockMvc;
  @Autowired private JwtProvider jwtProvider;
  @Autowired private MemberRepository memberRepository;
  @Autowired private GuardianshipService guardianshipService;
  @Autowired private SubscriptionService subscriptionService;
  @Autowired private ExpertRoutineRepository expertRoutineRepository;
  @Autowired private ExpertRoutineStepRepository expertRoutineStepRepository;
  @Autowired private RoutineRepository routineRepository;
  @Autowired private JdbcTemplate jdbcTemplate;
  @Autowired private TransactionTemplate transactionTemplate;

  @Test
  @DisplayName("Free 는 403 EXPERT_ROUTINE_PRO_ONLY, Pro 는 크레딧 흔적 없이 카드·보상이 든 원본 일과를 받는다")
  void freeIsRejected_proImportsWithoutCredits() throws Exception {
    ExpertRoutine visible = newExpertRoutine(true, ExpertRoutineReviewStatus.REVIEWED);
    Member free = newMember();
    Profile freeProfile = guardianshipService.createOwnProfile(free);

    String rejected = call(post("/api/expert-routines/" + visible.getId() + "/import"), free,
      "{\"profileId\":\"" + freeProfile.getId() + "\"}", 403);
    assertThat(rejected).contains("EXPERT_ROUTINE_PRO_ONLY");

    Member pro = newMember();
    Profile proProfile = guardianshipService.createOwnProfile(pro);
    subscriptionService.grantPro(pro.getId(), 30, "리허설", "it1076");
    long creditJobsBefore = countRows("ai_credit_job");
    long creditLedgerBefore = countRows("ai_credit_ledger");

    String imported = call(post("/api/expert-routines/" + visible.getId() + "/import"), pro,
      "{\"profileId\":\"" + proProfile.getId() + "\"}", 200);

    String routineId = JsonPath.read(imported, "$.routineId");
    transactionTemplate.executeWithoutResult(status -> {
      Routine routine = routineRepository.findById(routineId).orElseThrow();
      assertThat(routine.getTitle()).isEqualTo(visible.getTitle());
      assertThat(routine.getTalkPostId()).isNull();
      assertThat(routine.isLibraryOnly()).isTrue();
      assertThat(routine.getRewardText()).isEqualTo("칭찬 스티커");
      assertThat(routine.getSteps()).extracting(RoutineStep::getDescription).containsExactly("손을 씻어요", "손을 닦아요");
      assertThat(routine.getSteps()).extracting(RoutineStep::getPictogramId).containsExactly("wash_hands_,_to", "dry_hands_,_to");
    });
    assertThat(countRows("ai_credit_job")).isEqualTo(creditJobsBefore);
    assertThat(countRows("ai_credit_ledger")).isEqualTo(creditLedgerBefore);
    assertThat(expertRoutineRepository.findById(visible.getId()).orElseThrow().getImportCount()).isEqualTo(1);
  }

  @Test
  @DisplayName("목록·미리 보기: 검수 전 · 숨긴 일과는 안 보이고 404, 공개 + 검수 완료만 보인다")
  void listShowsOnlyPublishedReviewed() throws Exception {
    ExpertRoutine visible = newExpertRoutine(true, ExpertRoutineReviewStatus.REVIEWED);
    ExpertRoutine draft = newExpertRoutine(true, ExpertRoutineReviewStatus.DRAFT);
    ExpertRoutine hidden = newExpertRoutine(false, ExpertRoutineReviewStatus.REVIEWED);
    Member member = newMember();

    String list = call(get("/api/expert-routines").param("category", "SELF_CARE"), member, null, 200);

    List<String> ids = JsonPath.read(list, "$[*].id");
    assertThat(ids).contains(visible.getId()).doesNotContain(draft.getId(), hidden.getId());
    assertThat(JsonPath.<List<String>>read(list, "$[?(@.id=='" + visible.getId() + "')].coverPictogramId"))
      .containsExactly("wash_hands_,_to");
    call(get("/api/expert-routines/" + draft.getId()), member, null, 404);
    call(get("/api/expert-routines/" + hidden.getId()), member, null, 404);
    String detail = call(get("/api/expert-routines/" + visible.getId()), member, null, 200);
    assertThat(JsonPath.<List<String>>read(detail, "$.steps[*].text")).containsExactly("손을 씻어요", "손을 닦아요");
  }

  // ── 준비물 ──

  private ExpertRoutine newExpertRoutine(boolean isPublished, ExpertRoutineReviewStatus reviewStatus) {
    ExpertRoutine routine = new ExpertRoutine();
    routine.setTitle("it1076 손 씻기 " + UUID.randomUUID().toString().substring(0, 8));
    routine.setCategory(TalkCategory.SELF_CARE);
    routine.setLanguage(AppLocale.KO);
    routine.setRewardText("칭찬 스티커");
    routine.setReviewStatus(reviewStatus);
    routine.setPublished(isPublished);
    routine.setStepCount(2);
    ExpertRoutine saved = expertRoutineRepository.save(routine);
    expertRoutineStepRepository.saveAll(List.of(
      step(saved.getId(), 0, "손을 씻어요", "wash_hands_,_to"),
      step(saved.getId(), 1, "손을 닦아요", "dry_hands_,_to")));
    return saved;
  }

  private static ExpertRoutineStep step(String expertRoutineId, int order, String text, String pictogramId) {
    ExpertRoutineStep step = new ExpertRoutineStep();
    step.setExpertRoutineId(expertRoutineId);
    step.setStepOrder(order);
    step.setText(text);
    step.setPictogramId(pictogramId);
    return step;
  }

  private Member newMember() {
    Member member = new Member();
    member.setUsername("it1076_" + UUID.randomUUID());
    member.setPassword("x");
    member.setTermsAgreed(true);
    member.setPrivacyAgreed(true);
    member.setOverseasTransferAgreed(true);
    member.setGuardianConfirmed(true);
    return memberRepository.save(member);
  }

  private long countRows(String table) {
    Long count = jdbcTemplate.queryForObject("select count(*) from " + table, Long.class);
    return count == null ? 0 : count;
  }

  private String call(MockHttpServletRequestBuilder request, Member as, String body, int expectedStatus)
    throws Exception {
    request.header("Authorization", "Bearer " + jwtProvider.createAccessToken(as.getId(), as.getUsername()));
    if (body != null) {
      request.contentType(MediaType.APPLICATION_JSON).content(body);
    }
    MvcResult response = mockMvc.perform(request).andReturn();
    assertThat(response.getResponse().getStatus())
      .as(request + " → " + response.getResponse().getContentAsString())
      .isEqualTo(expectedStatus);
    return response.getResponse().getContentAsString();
  }
}
