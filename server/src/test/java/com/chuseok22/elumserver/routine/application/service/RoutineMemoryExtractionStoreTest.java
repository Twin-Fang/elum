package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.core.RoutineMemoryExtractionState;
import com.chuseok22.elumserver.routine.core.RoutineMemoryFinding;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineMemoryAi;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEdit;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEvidence;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRejection;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEditRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEvidenceRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRejectionRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 수정 찾기 선점·반영: 깨지면 한 번 고친 것이 바로 적용되거나, 같은 일과가 두 번 세어지거나,
 * 끈·지운 규칙이 되살아나거나, 카드에 없는 낱말·남의 규칙이 규칙·근거가 된다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryExtractionStoreTest {

  private static final String PROFILE_ID = "profile-1";
  private static final String MEMBER_A = "member-a";
  private static final String MEMBER_B = "member-b";
  private static final List<RoutineCardText> FIRST = List.of(new RoutineCardText("옷", "겉옷을 착용해요"));
  private static final List<RoutineCardText> CONFIRMED = List.of(new RoutineCardText("옷", "겉옷을 입어요"));
  private static final RoutineMemoryFinding WORD_FINDING =
    new RoutineMemoryFinding(RoutineMemoryRuleType.WORD, "착용해요", "입어요", "착용해요 대신 입어요");

  @Mock private RoutineRepository routineRepository;
  @Mock private EntitlementService entitlementService;
  @Mock private RoutineMemorySettings routineMemorySettings;
  @Mock private RoutineMemoryRuleRepository ruleRepository;
  @Mock private RoutineMemoryEvidenceRepository evidenceRepository;
  @Mock private RoutineMemoryEditRepository editRepository;
  @Mock private RoutineMemoryRejectionRepository rejectionRepository;
  @Mock private RoutineMemoryPolicy policy;
  @InjectMocks private RoutineMemoryExtractionStore store;

  /// 메모리 안 저장소: 규칙·근거·거절 기억
  private final List<RoutineMemoryRule> rules = new ArrayList<>();
  private final List<RoutineMemoryEvidence> evidences = new ArrayList<>();
  private final List<RoutineMemoryRejection> rejections = new ArrayList<>();
  private final List<RoutineMemoryEdit> edits = new ArrayList<>();

  @BeforeEach
  void setUp() {
    lenient().when(policy.autoApplyCount()).thenReturn(3);
    lenient().when(ruleRepository.findAllByProfileIdAndMemberId(anyString(), anyString())).thenAnswer(call ->
      rules.stream().filter(rule -> rule.getProfileId().equals(call.getArgument(0))
        && rule.getMemberId().equals(call.getArgument(1))).toList());
    lenient().when(ruleRepository.save(any(RoutineMemoryRule.class))).thenAnswer(call -> {
      RoutineMemoryRule rule = call.getArgument(0);
      if (rule.getId() == null) {
        rule.setId(UUID.randomUUID().toString());
        rules.add(rule);
      }
      return rule;
    });
    lenient().when(evidenceRepository.existsByRuleIdAndRoutineId(anyString(), anyString())).thenAnswer(call ->
      evidences.stream().anyMatch(evidence -> evidence.getRuleId().equals(call.getArgument(0))
        && evidence.getRoutineId().equals(call.getArgument(1))));
    lenient().when(evidenceRepository.save(any(RoutineMemoryEvidence.class))).thenAnswer(call -> {
      evidences.add(call.getArgument(0));
      return call.getArgument(0);
    });
    lenient().when(rejectionRepository.findAllByProfileIdAndMemberId(anyString(), anyString())).thenAnswer(call ->
      rejections.stream().filter(rejection -> rejection.getMemberId().equals(call.getArgument(1))).toList());
    lenient().when(editRepository.save(any(RoutineMemoryEdit.class))).thenAnswer(call -> {
      edits.add(call.getArgument(0));
      return call.getArgument(0);
    });
    lenient().when(editRepository.findByRoutineId(anyString())).thenAnswer(call ->
      edits.stream().filter(edit -> edit.getRoutineId().equals(call.getArgument(0))).findFirst());
  }

  private static RoutineMemoryExtractionStore.ExtractionJob job(String routineId, String memberId) {
    return new RoutineMemoryExtractionStore.ExtractionJob(routineId, "아침 준비", PROFILE_ID, memberId, AppLocale.KO,
      FIRST, CONFIRMED, RoutineMemoryAi.ExtractionInput.of(List.of(), List.of(), List.of(), List.of()));
  }

  private static RoutineMemoryAi.ExtractionResult found(RoutineMemoryFinding... findings) {
    return new RoutineMemoryAi.ExtractionResult(List.of(), List.of(findings));
  }

  private static RoutineMemoryAi.ExtractionResult matched(String... ruleIds) {
    return new RoutineMemoryAi.ExtractionResult(List.of(ruleIds), List.of());
  }

  private RoutineMemoryRule existingRule(String memberId, RoutineMemoryRuleStatus status, int evidenceCount) {
    RoutineMemoryRule rule = new RoutineMemoryRule();
    rule.setId(UUID.randomUUID().toString());
    rule.setProfileId(PROFILE_ID);
    rule.setMemberId(memberId);
    rule.setType(RoutineMemoryRuleType.WORD);
    rule.setStatus(status);
    rule.setSource(RoutineMemoryRuleSource.AI);
    rule.setSummary("착용해요 대신 입어요");
    rule.setBeforeText("착용해요");
    rule.setAfterText("입어요");
    rule.setEvidenceCount(evidenceCount);
    rules.add(rule);
    return rule;
  }

  // --- 세기·적용 ---

  @Test
  @DisplayName("한 번 고친 것은 관찰 중(WATCHING)으로만 쌓인다 — 한 번 고쳤다고 다음 일과에 바로 적용되면 안 된다")
  void oneObservation_staysWatching() {
    store.apply(job("r1", MEMBER_A), found(WORD_FINDING));

    assertThat(rules).singleElement().satisfies(rule -> {
      assertThat(rule.getStatus()).isEqualTo(RoutineMemoryRuleStatus.WATCHING);
      assertThat(rule.getSource()).isEqualTo(RoutineMemoryRuleSource.AI);
      assertThat(rule.getEvidenceCount()).isEqualTo(1);
      assertThat(rule.getSummary()).isEqualTo("착용해요 대신 입어요");
    });
  }

  @Test
  @DisplayName("같은 수정이 서로 다른 일과 3개에서 관찰되면 ACTIVE 가 된다 — AI 가 짝을 못 지어도 규칙은 하나다")
  void threeDifferentRoutines_becomeActiveWithOneRule() {
    store.apply(job("r1", MEMBER_A), found(WORD_FINDING));
    store.apply(job("r2", MEMBER_A), found(WORD_FINDING));
    assertThat(rules).singleElement().satisfies(rule ->
      assertThat(rule.getStatus()).isEqualTo(RoutineMemoryRuleStatus.WATCHING));

    store.apply(job("r3", MEMBER_A), found(WORD_FINDING));

    assertThat(rules).singleElement().satisfies(rule -> {
      assertThat(rule.getStatus()).isEqualTo(RoutineMemoryRuleStatus.ACTIVE);
      assertThat(rule.getEvidenceCount()).isEqualTo(3);
    });
    assertThat(evidences).hasSize(3);
  }

  @Test
  @DisplayName("같은 일과를 두 번 처리해도 한 번만 센다 — 한 일과가 3번 센 것으로 자동 적용된다")
  void sameRoutineTwice_countsOnce() {
    store.apply(job("r1", MEMBER_A), found(WORD_FINDING));
    store.apply(job("r1", MEMBER_A), found(WORD_FINDING));
    RoutineMemoryRule rule = rules.get(0);
    store.apply(job("r1", MEMBER_A), matched(rule.getId()));

    assertThat(rules).hasSize(1);
    assertThat(rule.getEvidenceCount()).isEqualTo(1);
    assertThat(rule.getStatus()).isEqualTo(RoutineMemoryRuleStatus.WATCHING);
    assertThat(evidences).hasSize(1);
  }

  @Test
  @DisplayName("보호자가 끈(OFF) 규칙은 근거가 쌓여도 켜지지 않는다")
  void offRule_staysOffEvenAtThreshold() {
    RoutineMemoryRule off = existingRule(MEMBER_A, RoutineMemoryRuleStatus.OFF, 2);

    store.apply(job("r3", MEMBER_A), matched(off.getId()));

    assertThat(off.getEvidenceCount()).isEqualTo(3);
    assertThat(off.getStatus()).isEqualTo(RoutineMemoryRuleStatus.OFF);
  }

  // --- 거절·검증 ---

  @Test
  @DisplayName("보호자가 지운 규칙과 같은 수정은 AI 가 다시 가져와도 되살리지 않는다")
  void rejectedRule_isNotRevived() {
    RoutineMemoryRejection rejection = new RoutineMemoryRejection();
    rejection.setProfileId(PROFILE_ID);
    rejection.setMemberId(MEMBER_A);
    rejection.setType(RoutineMemoryRuleType.WORD);
    rejection.setBeforeText("착용해요");
    rejection.setAfterText("입어요");
    rejections.add(rejection);

    store.apply(job("r1", MEMBER_A), found(WORD_FINDING));

    assertThat(rules).isEmpty();
    assertThat(evidences).isEmpty();
  }

  @Test
  @DisplayName("before 가 카드에 없는 found 는 버린다 — AI 가 지어낸 낱말이 규칙이 된다")
  void foundWithWordNotInCards_isDropped() {
    RoutineMemoryFinding invented = new RoutineMemoryFinding(RoutineMemoryRuleType.WORD, "벗어요", "입어요", null);

    RoutineMemoryExtractionStore.ApplyResult result = store.apply(job("r1", MEMBER_A), found(invented));

    assertThat(rules).isEmpty();
    assertThat(result.droppedCount()).isEqualTo(1);
  }

  @Test
  @DisplayName("matched 에 남의 규칙 id 가 오면 버린다 — 다른 보호자의 규칙에 내 근거가 쌓인다")
  void matchedWithOtherGuardiansRule_isDropped() {
    RoutineMemoryRule othersRule = existingRule(MEMBER_B, RoutineMemoryRuleStatus.WATCHING, 0);

    RoutineMemoryExtractionStore.ApplyResult result = store.apply(job("r1", MEMBER_A), matched(othersRule.getId()));

    assertThat(othersRule.getEvidenceCount()).isZero();
    assertThat(evidences).isEmpty();
    assertThat(result.droppedCount()).isEqualTo(1);
  }

  @Test
  @DisplayName("matched 한 규칙이 이번 카드에서 실제로 보이지 않으면 버린다 — AI 가 엉뚱한 규칙에 짝지어 횟수가 부푼다")
  void matchedRuleNotVisibleInCards_isDropped() {
    RoutineMemoryRule rule = existingRule(MEMBER_A, RoutineMemoryRuleStatus.WATCHING, 0);
    rule.setBeforeText("씻어요");
    rule.setAfterText("닦아요");

    store.apply(job("r1", MEMBER_A), matched(rule.getId()));

    assertThat(rule.getEvidenceCount()).isZero();
    assertThat(evidences).isEmpty();
  }

  @Test
  @DisplayName("직접 적은 규칙은 AI 짝짓기로 근거가 쌓이지 않는다")
  void manualRule_isNeverMatched() {
    RoutineMemoryRule manual = existingRule(MEMBER_A, RoutineMemoryRuleStatus.ACTIVE, 0);
    manual.setType(RoutineMemoryRuleType.MANUAL);
    manual.setSource(RoutineMemoryRuleSource.MANUAL);

    store.apply(job("r1", MEMBER_A), matched(manual.getId()));

    assertThat(manual.getEvidenceCount()).isZero();
  }

  @Test
  @DisplayName("한 일과에서 새 수정은 최대 5개까지만 받는다")
  void foundIsLimitedToFive() {
    List<RoutineCardText> first = new ArrayList<>();
    List<RoutineCardText> confirmed = new ArrayList<>();
    RoutineMemoryFinding[] findings = new RoutineMemoryFinding[7];
    for (int index = 0; index < 7; index++) {
      first.add(new RoutineCardText("카드" + index, "옛말" + index + "해요"));
      confirmed.add(new RoutineCardText("카드" + index, "새말" + index + "해요"));
      findings[index] = new RoutineMemoryFinding(RoutineMemoryRuleType.WORD, "옛말" + index, "새말" + index, null);
    }
    var wideJob = new RoutineMemoryExtractionStore.ExtractionJob("r1", "아침", PROFILE_ID, MEMBER_A, AppLocale.KO,
      first, confirmed, RoutineMemoryAi.ExtractionInput.of(List.of(), List.of(), List.of(), List.of()));

    store.apply(wideJob, found(findings));

    assertThat(rules).hasSize(5);
  }

  @Test
  @DisplayName("수정 기록은 반영이 끝나면 DONE 이 된다")
  void apply_marksEditDone() {
    RoutineMemoryEdit edit = new RoutineMemoryEdit();
    edit.setRoutineId("r1");
    edits.add(edit);

    store.apply(job("r1", MEMBER_A), found(WORD_FINDING));

    assertThat(edit.getExtractionState()).isEqualTo(RoutineMemoryExtractionState.DONE);
  }

  // --- 선점 ---

  private Routine confirmedRoutine(List<RoutineCardText> firstCards, List<RoutineCardText> confirmedCards) {
    Routine routine = new Routine();
    routine.setId("r1");
    routine.setTitle("아침 준비");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setCreatedBy(MEMBER_A);
    routine.setLanguage(AppLocale.KO);
    Profile profile = new Profile();
    profile.setId(PROFILE_ID);
    profile.setNickname("하늘이");
    routine.setProfile(profile);
    routine.setAiDraftCards(RoutineMemoryJson.writeCards(firstCards));
    List<RoutineStep> steps = new ArrayList<>();
    for (int index = 0; index < confirmedCards.size(); index++) {
      RoutineStep step = new RoutineStep();
      step.setStepOrder(index + 1);
      step.setTitle(confirmedCards.get(index).title());
      step.setDescription(confirmedCards.get(index).description());
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }

  private void givenClaimable(Routine routine, boolean isPro, boolean isEnabled) {
    when(routineRepository.findById("r1")).thenReturn(Optional.of(routine));
    when(routineRepository.claimMemoryExtraction(anyString(), any())).thenReturn(1);
    lenient().when(entitlementService.isAllowed(MEMBER_A, Entitlement.ROUTINE_MEMORY)).thenReturn(isPro);
    lenient().when(routineMemorySettings.isEnabled(PROFILE_ID, MEMBER_A)).thenReturn(isEnabled);
  }

  @Test
  @DisplayName("고쳐 확정한 Pro 일과는 수정 기록(카드 수 전·후, 바뀐 글 수)을 남기고 AI 입력엔 이름 대신 자리표시를 쓴다")
  void claim_savesEditRecordAndMasksName() {
    List<RoutineCardText> first = List.of(new RoutineCardText("하늘이 옷", "하늘이가 착용해요"));
    List<RoutineCardText> confirmed = List.of(new RoutineCardText("하늘이 옷", "하늘이가 입어요"),
      new RoutineCardText("신발", "신발을 신어요"));
    givenClaimable(confirmedRoutine(first, confirmed), true, true);
    RoutineMemoryRule manual = existingRule(MEMBER_A, RoutineMemoryRuleStatus.ACTIVE, 0);
    manual.setType(RoutineMemoryRuleType.MANUAL);
    manual.setSummary("카드 글은 10자 안으로");

    Optional<RoutineMemoryExtractionStore.ExtractionJob> job = store.claim("r1");

    assertThat(job).isPresent();
    assertThat(edits).singleElement().satisfies(edit -> {
      assertThat(edit.getCardCountBefore()).isEqualTo(1);
      assertThat(edit.getCardCountAfter()).isEqualTo(2);
      assertThat(edit.getChangedTextCount()).isEqualTo(2);
      assertThat(edit.getExtractionState()).isEqualTo(RoutineMemoryExtractionState.PENDING);
    });
    assertThat(job.get().input().firstCards()).containsExactly("이룸이 옷 / 이룸이가 착용해요");
    assertThat(job.get().input().existingRules()).isEmpty();
  }

  @Test
  @DisplayName("메모리가 꺼져 있으면 AI 입력을 만들지 않고 수정 기록도 남기지 않는다 (같은 일과를 다시 보지 않게 표시만)")
  void claim_disabled_returnsEmpty() {
    givenClaimable(confirmedRoutine(FIRST, List.of(new RoutineCardText("옷", "겉옷을 입어요"))), true, false);

    assertThat(store.claim("r1")).isEmpty();
    assertThat(edits).isEmpty();
    verify(routineRepository).claimMemoryExtraction(anyString(), any());
  }

  @Test
  @DisplayName("Pro 가 아니면 찾지 않는다")
  void claim_notPro_returnsEmpty() {
    givenClaimable(confirmedRoutine(FIRST, CONFIRMED), false, true);

    assertThat(store.claim("r1")).isEmpty();
    assertThat(edits).isEmpty();
  }

  @Test
  @DisplayName("보호자가 고치지 않은 일과는 찾지 않는다")
  void claim_unedited_returnsEmpty() {
    givenClaimable(confirmedRoutine(FIRST, FIRST), true, true);

    assertThat(store.claim("r1")).isEmpty();
    assertThat(edits).isEmpty();
  }

  @Test
  @DisplayName("이미 다른 쪽이 선점한 일과는 다시 처리하지 않는다 — 같은 일과를 두 번 AI 로 보낸다")
  void claim_alreadyClaimed_returnsEmpty() {
    when(routineRepository.findById("r1")).thenReturn(Optional.of(confirmedRoutine(FIRST, CONFIRMED)));
    when(routineRepository.claimMemoryExtraction(anyString(), any())).thenReturn(0);

    assertThat(store.claim("r1")).isEmpty();
    verify(entitlementService, never()).isAllowed(anyString(), any());
  }

  @Test
  @DisplayName("임시저장(확정 전) 일과는 선점하지 않는다")
  void claim_pendingReview_isNotClaimed() {
    Routine routine = confirmedRoutine(FIRST, CONFIRMED);
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    when(routineRepository.findById("r1")).thenReturn(Optional.of(routine));

    assertThat(store.claim("r1")).isEmpty();
    verify(routineRepository, never()).claimMemoryExtraction(anyString(), any());
  }
}
