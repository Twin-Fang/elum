package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryImportRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryImportRequest.ImportedRule;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryExportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryImportResponse;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 메모리 내보내기·가져오기: 깨지면 금지 낱말이 가져오기로 규칙에 들어오거나, 같은 규칙이 두 번 쌓이거나, 내보낸 파일에 개인 정보가 실린다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryPortabilityServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-a");
  private static final String PROFILE_ID = "profile-1";

  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private EntitlementService entitlementService;
  @Mock private RoutineMemoryRuleRepository ruleRepository;
  @InjectMocks private RoutineMemoryPortabilityService service;

  private final List<RoutineMemoryRule> existing = new ArrayList<>();

  @BeforeEach
  void setUp() {
    Profile profile = new Profile();
    profile.setId(PROFILE_ID);
    lenient().when(profileAccessGuard.profileFor(GUARDIAN, ProfileAction.MANAGE)).thenReturn(profile);
    lenient().when(ruleRepository.findAllByProfileIdAndMemberId(PROFILE_ID, "member-a")).thenReturn(existing);
  }

  private static ImportedRule word(String status, String before, String after) {
    return new ImportedRule("WORD", status, "AI", before + " 대신 " + after, before, after);
  }

  private static RoutineMemoryImportRequest request(ImportedRule... rules) {
    return new RoutineMemoryImportRequest(RoutineMemoryExportResponse.SCHEMA, List.of(rules));
  }

  @Test
  @DisplayName("필터에 걸리는 항목은 버리고 몇 개 넣고 몇 개 버렸는지 알려 준다")
  void import_rejectsForbiddenAndReportsCounts() {
    RoutineMemoryImportResponse response = service.importRules(GUARDIAN, request(
      word("ACTIVE", "착용해요", "입어요"),
      new ImportedRule("MANUAL", "ACTIVE", "MANUAL", "자폐라서 카드는 짧게", null, null),
      word("ACTIVE", "자폐", "일반"),
      new ImportedRule("SPLIT", "ACTIVE", "AI", "나눠요", null, "칫솔 들기 · 이 닦기"),
      new ImportedRule("MAGIC", "ACTIVE", "AI", "알 수 없는 종류", "가나", "다라")));

    assertThat(response.importedCount()).isEqualTo(1);
    assertThat(response.rejectedCount()).isEqualTo(4);
    verify(ruleRepository, org.mockito.Mockito.times(1)).save(any(RoutineMemoryRule.class));
  }

  @Test
  @DisplayName("같은 (종류, before, after, 요약)은 건너뛴다 — 두 번 가져오면 규칙이 두 배가 된다")
  void import_skipsDuplicates() {
    RoutineMemoryRule already = new RoutineMemoryRule();
    already.setType(RoutineMemoryRuleType.WORD);
    already.setBeforeText("착용해요");
    already.setAfterText("입어요");
    already.setSummary("착용해요 대신 입어요");
    existing.add(already);

    RoutineMemoryImportResponse response = service.importRules(GUARDIAN, request(
      word("ACTIVE", "착용해요", "입어요"), word("ACTIVE", "씻어요", "닦아요"), word("ACTIVE", "씻어요", "닦아요")));

    assertThat(response.importedCount()).isEqualTo(1);
    assertThat(response.duplicateCount()).isEqualTo(2);
  }

  @Test
  @DisplayName("가져온 규칙은 파일의 상태를 따르고 근거는 0 으로 시작한다 — WATCHING 이 근거 없이 ACTIVE 로 바뀌지 않는다")
  void import_keepsStatusAndStartsWithZeroEvidence() {
    service.importRules(GUARDIAN, request(word("WATCHING", "착용해요", "입어요"), word("OFF", "씻어요", "닦아요")));

    ArgumentCaptor<RoutineMemoryRule> saved = ArgumentCaptor.forClass(RoutineMemoryRule.class);
    verify(ruleRepository, org.mockito.Mockito.times(2)).save(saved.capture());
    assertThat(saved.getAllValues()).extracting(RoutineMemoryRule::getStatus)
      .containsExactly(RoutineMemoryRuleStatus.WATCHING, RoutineMemoryRuleStatus.OFF);
    assertThat(saved.getAllValues()).allSatisfy(rule -> {
      assertThat(rule.getEvidenceCount()).isZero();
      assertThat(rule.getMemberId()).isEqualTo("member-a");
      assertThat(rule.getSource()).isEqualTo(RoutineMemoryRuleSource.AI);
    });
  }

  @Test
  @DisplayName("모르는 schema 나 규칙 목록이 없는 파일은 400 으로 통째로 거절한다")
  void import_unknownSchema_rejected() {
    assertThatThrownBy(() -> service.importRules(GUARDIAN, new RoutineMemoryImportRequest("other.v9", List.of())))
      .satisfies(thrown -> assertThat(((CustomException) thrown).getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    assertThatThrownBy(() -> service.importRules(GUARDIAN,
      new RoutineMemoryImportRequest(RoutineMemoryExportResponse.SCHEMA, null)))
      .satisfies(thrown -> assertThat(((CustomException) thrown).getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    verify(ruleRepository, never()).save(any());
  }

  @Test
  @DisplayName("내보내기는 규칙의 종류·상태·출처·요약·before·after 만 싣는다 — 이름·회원 식별값·근거 일과 제목이 없다")
  void export_hasOnlyRuleFields() {
    RoutineMemoryRule rule = new RoutineMemoryRule();
    rule.setId("rule-1");
    rule.setMemberId("member-a");
    rule.setType(RoutineMemoryRuleType.WORD);
    rule.setStatus(RoutineMemoryRuleStatus.ACTIVE);
    rule.setSource(RoutineMemoryRuleSource.AI);
    rule.setSummary("착용해요 대신 입어요");
    rule.setBeforeText("착용해요");
    rule.setAfterText("입어요");
    existing.add(rule);

    RoutineMemoryExportResponse response = service.export(GUARDIAN);

    assertThat(response.schema()).isEqualTo("elum.routine-memory.v1");
    assertThat(response.rules()).singleElement().satisfies(exported ->
      assertThat(exported).isEqualTo(new RoutineMemoryExportResponse.ExportedRule(RoutineMemoryRuleType.WORD,
        RoutineMemoryRuleStatus.ACTIVE, RoutineMemoryRuleSource.AI, "착용해요 대신 입어요", "착용해요", "입어요")));
    assertThat(RoutineMemoryExportResponse.ExportedRule.class.getRecordComponents()).extracting(c -> c.getName())
      .containsExactly("type", "status", "source", "summary", "before", "after");
  }
}
