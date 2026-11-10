package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryObservationResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryObservationResponse.Status;
import com.chuseok22.elumserver.routine.core.RoutineMemoryExtractionState;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEdit;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEvidence;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEditRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEvidenceRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 방금 보낸 일과에서 찾은 수정: 깨지면 앱이 "다음에도 이렇게 할까요?"를 엉뚱한 때 띄우거나 영영 안 띄우고, 남의 일과 정보가 샌다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryObservationServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-a");
  private static final String PROFILE_ID = "profile-1";

  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private EntitlementService entitlementService;
  @Mock private RoutineRepository routineRepository;
  @Mock private RoutineMemoryEditRepository editRepository;
  @Mock private RoutineMemoryEvidenceRepository evidenceRepository;
  @Mock private RoutineMemoryRuleRepository ruleRepository;
  @Mock private RoutineMemorySettings settings;
  @InjectMocks private RoutineMemoryObservationService service;

  @BeforeEach
  void setUp() {
    Profile profile = new Profile();
    profile.setId(PROFILE_ID);
    lenient().when(profileAccessGuard.profileFor(GUARDIAN, ProfileAction.MANAGE)).thenReturn(profile);
    lenient().when(entitlementService.isAllowed("member-a", Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    lenient().when(settings.isEnabled(PROFILE_ID, "member-a")).thenReturn(true);
  }

  private Routine routine(String createdBy, String draftCards, LocalDateTime reflectedAt) {
    Routine routine = new Routine();
    routine.setId("r1");
    routine.setCreatedBy(createdBy);
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setAiDraftCards(draftCards);
    routine.setMemoryReflectedAt(reflectedAt);
    Profile profile = new Profile();
    profile.setId(PROFILE_ID);
    routine.setProfile(profile);
    when(routineRepository.findById("r1")).thenReturn(Optional.of(routine));
    return routine;
  }

  private void givenEdit(RoutineMemoryExtractionState state) {
    RoutineMemoryEdit edit = new RoutineMemoryEdit();
    edit.setExtractionState(state);
    when(editRepository.findByRoutineId("r1")).thenReturn(Optional.of(edit));
  }

  @Test
  @DisplayName("남의 일과이거나 없는 일과는 NONE 이다 — 다른 보호자 일과의 존재·결과가 새지 않는다")
  void otherGuardiansRoutine_isNone() {
    routine("member-b", "[]", null);

    assertThat(service.observationsOf(GUARDIAN, "r1").status()).isEqualTo(Status.NONE);
    when(routineRepository.findById("r2")).thenReturn(Optional.empty());
    assertThat(service.observationsOf(GUARDIAN, "r2").status()).isEqualTo(Status.NONE);
  }

  @Test
  @DisplayName("확정했지만 아직 아무도 선점하지 않았거나 찾는 중이면 PENDING 이다")
  void notClaimedYetOrRunning_isPending() {
    routine("member-a", "[]", null);
    when(editRepository.findByRoutineId("r1")).thenReturn(Optional.empty());
    assertThat(service.observationsOf(GUARDIAN, "r1").status()).isEqualTo(Status.PENDING);

    givenEdit(RoutineMemoryExtractionState.PENDING);
    assertThat(service.observationsOf(GUARDIAN, "r1").status()).isEqualTo(Status.PENDING);
  }

  @Test
  @DisplayName("선점됐는데 수정 기록이 없으면(고친 게 없음·꺼짐·Pro 아님) NONE 이다 — 앱이 끝없이 기다린다")
  void claimedWithoutEdit_isNone() {
    routine("member-a", "[]", LocalDateTime.now());
    when(editRepository.findByRoutineId("r1")).thenReturn(Optional.empty());

    assertThat(service.observationsOf(GUARDIAN, "r1").status()).isEqualTo(Status.NONE);
  }

  @Test
  @DisplayName("찾기가 끝나 근거로 잡힌 규칙이 있으면 READY, 끈 규칙은 뺀다. AI 실패는 NONE")
  void done_returnsItemsWithoutOffRules() {
    routine("member-a", "[]", LocalDateTime.now());
    givenEdit(RoutineMemoryExtractionState.DONE);
    RoutineMemoryEvidence evidenceA = new RoutineMemoryEvidence();
    evidenceA.setRuleId("rule-a");
    RoutineMemoryEvidence evidenceB = new RoutineMemoryEvidence();
    evidenceB.setRuleId("rule-b");
    when(evidenceRepository.findAllByRoutineId("r1")).thenReturn(List.of(evidenceA, evidenceB));
    when(ruleRepository.findAllByIdInAndProfileIdAndMemberId(List.of("rule-a", "rule-b"), PROFILE_ID, "member-a"))
      .thenReturn(List.of(rule("rule-a", RoutineMemoryRuleStatus.WATCHING, 2), rule("rule-b", RoutineMemoryRuleStatus.OFF, 3)));

    RoutineMemoryObservationResponse response = service.observationsOf(GUARDIAN, "r1");

    assertThat(response.status()).isEqualTo(Status.READY);
    assertThat(response.items()).singleElement().satisfies(item -> {
      assertThat(item.ruleId()).isEqualTo("rule-a");
      assertThat(item.evidenceCount()).isEqualTo(2);
      assertThat(item.ruleStatus()).isEqualTo(RoutineMemoryRuleStatus.WATCHING);
    });
  }

  @Test
  @DisplayName("AI 가 실패했거나 근거가 없으면 NONE")
  void failedOrEmpty_isNone() {
    routine("member-a", "[]", LocalDateTime.now());
    givenEdit(RoutineMemoryExtractionState.FAILED);
    assertThat(service.observationsOf(GUARDIAN, "r1").status()).isEqualTo(Status.NONE);

    givenEdit(RoutineMemoryExtractionState.DONE);
    when(evidenceRepository.findAllByRoutineId("r1")).thenReturn(List.of());
    assertThat(service.observationsOf(GUARDIAN, "r1").status()).isEqualTo(Status.NONE);
  }

  private static RoutineMemoryRule rule(String id, RoutineMemoryRuleStatus status, int evidenceCount) {
    RoutineMemoryRule rule = new RoutineMemoryRule();
    rule.setId(id);
    rule.setType(RoutineMemoryRuleType.WORD);
    rule.setStatus(status);
    rule.setSummary("착용해요 대신 입어요");
    rule.setBeforeText("착용해요");
    rule.setAfterText("입어요");
    rule.setEvidenceCount(evidenceCount);
    return rule;
  }
}
