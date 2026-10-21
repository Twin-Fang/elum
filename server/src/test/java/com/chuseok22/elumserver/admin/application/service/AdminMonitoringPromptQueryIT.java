package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMonitoringList;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateHistoryRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * 실제 Postgres 로 하는 모니터링 목록 쿼리와 프롬프트 수정자 기록 검증 (#758). 평소 빌드에서는 건너뛴다.
 * 기간·호출 유형·결과·회원 필터가 실제 Specification 으로 도는지, changed_by 가 저장되는지 본다.
 * ELUM_IT_DDL_AUTO=validate 로 돌리면 엔티티와 DB 스키마(V41 적용 후)가 맞는지도 함께 본다.
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54758/elum ./gradlew test --tests '*AdminMonitoringPromptQueryIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=elum",
  "spring.datasource.password=pw",
  "spring.flyway.enabled=false",
  "spring.jpa.hibernate.ddl-auto=${ELUM_IT_DDL_AUTO:update}",
  "gemini.api-key=rehearsal-invalid"
})
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class AdminMonitoringPromptQueryIT {

  @Autowired private AdminMonitoringService adminMonitoringService;
  @Autowired private AiCallLogRepository aiCallLogRepository;
  @Autowired private PromptTemplateService promptTemplateService;
  @Autowired private PromptTemplateRepository promptTemplateRepository;
  @Autowired private PromptTemplateHistoryRepository promptTemplateHistoryRepository;

  private final String memberId = "it758_" + UUID.randomUUID().toString().substring(0, 8);

  @AfterEach
  void cleanUp() {
    aiCallLogRepository.findAll().stream().filter(log -> memberId.equals(log.getMemberId()))
      .forEach(aiCallLogRepository::delete);
  }

  private AiCallLog newCall(AiCallType type, boolean success) {
    AiCallLog log = new AiCallLog();
    log.setMemberId(memberId);
    log.setCallType(type);
    log.setSuccess(success);
    return aiCallLogRepository.save(log);
  }

  private List<String> search(String callType, String success, String from, String to) {
    Map<String, String> filters = new HashMap<>();
    filters.put("callType", callType);
    filters.put("success", success);
    filters.put("memberId", memberId);
    filters.put("from", from);
    filters.put("to", to);
    AdminListQuery query = AdminMonitoringList.withCorrectedPeriod(
      AdminListQuery.of(null, filters, null, null, AdminMonitoringList.DEFINITION), LocalDate.now());
    return adminMonitoringService.search(query).getContent().stream().map(AiCallLog::getId).toList();
  }

  @Test
  @DisplayName("회원·기간·유형·결과 필터가 실제 쿼리로 걸러진다")
  void filtersWork() {
    AiCallLog okImage = newCall(AiCallType.GEMINI_IMAGE, true);
    AiCallLog failedText = newCall(AiCallType.GEMINI_TEXT_CREATE, false);
    String today = LocalDate.now().toString();

    assertThat(search(null, null, null, null)).containsExactlyInAnyOrder(okImage.getId(), failedText.getId());
    assertThat(search("GEMINI_IMAGE", null, null, null)).containsExactly(okImage.getId());
    assertThat(search(null, "false", null, null)).containsExactly(failedText.getId());
    assertThat(search("GEMINI_IMAGE", "false", null, null)).isEmpty();
    // 오늘 하루, 어제까지만 → 오늘 기록은 빠진다, 시작·종료가 뒤집혀도 같은 결과
    assertThat(search(null, null, today, today)).hasSize(2);
    assertThat(search(null, null, LocalDate.now().minusDays(30).toString(),
      LocalDate.now().minusDays(1).toString())).isEmpty();
    assertThat(search(null, null, today, LocalDate.now().minusDays(1).toString())).hasSize(2);
  }

  @Test
  @DisplayName("모델명·오류 메시지는 대소문자 무시 포함 검색, 회원 검색은 회원 ID 그대로도 찾는다 (서브쿼리가 실제 SQL 로 돈다)")
  void modelErrorAndMemberSearchWork() {
    AiCallLog gemini = newCall(AiCallType.GEMINI_TEXT_CREATE, false);
    gemini.setModel("gemini-2.5-flash");
    gemini.setErrorMessage("Read TIMEOUT after 30s");
    aiCallLogRepository.save(gemini);
    AiCallLog openAi = newCall(AiCallType.GEMINI_IMAGE, true);
    openAi.setModel("gpt-image-1-mini");
    aiCallLogRepository.save(openAi);

    assertThat(searchBy(Map.of("model", "GEMINI"))).containsExactly(gemini.getId());
    assertThat(searchBy(Map.of("error", "timeout"))).containsExactly(gemini.getId());
    assertThat(searchBy(Map.of("model", "100%"))).isEmpty();
    // 회원 ID 를 회원 칸에 그대로 넣어도 찾고, 없는 아이디·이메일 일부면 비어 있다
    assertThat(searchBy(Map.of("member", memberId))).containsExactlyInAnyOrder(gemini.getId(), openAi.getId());
    assertThat(searchBy(Map.of("member", "no-such-" + memberId))).isEmpty();
  }

  // 이 시험 회원으로 한정한 채 추가 필터만 바꿔 조회
  private List<String> searchBy(Map<String, String> extraFilters) {
    Map<String, String> filters = new HashMap<>(extraFilters);
    filters.put("memberId", memberId);
    AdminListQuery query = AdminMonitoringList.withCorrectedPeriod(
      AdminListQuery.of(null, filters, null, null, AdminMonitoringList.DEFINITION), LocalDate.now());
    return adminMonitoringService.search(query).getContent().stream().map(AiCallLog::getId).toList();
  }

  @Test
  @DisplayName("프롬프트를 저장하면 이력에 changed_by 가 채워지고, 키별 최근 수정자로 읽힌다")
  void promptChangedByIsRecorded() {
    PromptKey key = PromptKey.GEMINI_ROUTINE_CREATE_PREFIX;
    PromptTemplate template = promptTemplateRepository.findByPromptKeyAndLocale(key, "ko").orElseGet(() -> {
      PromptTemplate created = new PromptTemplate();
      created.setPromptKey(key);
      created.setLocale("ko");
      created.setContent("it758 seed");
      return promptTemplateRepository.save(created);
    });
    String originalContent = template.getContent();
    String changer = "it758-" + UUID.randomUUID().toString().substring(0, 6);

    promptTemplateService.update(key, AppLocale.KO, originalContent + " it758", changer);
    try {
      PromptTemplateHistory latest = promptTemplateService.getHistory(key, AppLocale.KO).get(0);
      assertThat(latest.getChangedBy()).isEqualTo(changer);
      assertThat(promptTemplateService.getLatestChangerByKey(AppLocale.KO)).containsEntry(key, changer);
    } finally {
      // 운영 데이터가 아닌 로컬 임시 DB 지만 원래 내용으로 되돌리고 이번 이력 행을 지운다
      promptTemplateRepository.findByPromptKeyAndLocale(key, "ko").ifPresent(row -> {
        row.setContent(originalContent);
        promptTemplateRepository.save(row);
      });
      promptTemplateHistoryRepository.findAll().stream().filter(history -> changer.equals(history.getChangedBy()))
        .forEach(promptTemplateHistoryRepository::delete);
    }
  }
}
