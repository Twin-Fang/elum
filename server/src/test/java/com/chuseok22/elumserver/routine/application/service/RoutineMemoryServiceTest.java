package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryRuleUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRejection;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEditRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEvidenceRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRejectionRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemorySettingRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 보호자의 AI 메모리 관리: 깨지면 금지 낱말이 규칙이 되거나, 지운 규칙이 되살아나거나, 남의 규칙을 고치거나, 나간 보호자의 규칙이 남는다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-a");
  private static final String PROFILE_ID = "profile-1";

  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private EntitlementService entitlementService;
  @Mock private RoutineMemoryRuleRepository ruleRepository;
  @Mock private RoutineMemoryEvidenceRepository evidenceRepository;
  @Mock private RoutineMemoryEditRepository editRepository;
  @Mock private RoutineMemoryRejectionRepository rejectionRepository;
  @Mock private RoutineMemorySettingRepository settingRepository;
  @Mock private RoutineMemorySettings settings;
  @Mock private RoutineMemoryResponseAssembler assembler;
  @Mock private RoutineMemoryPolicy policy;
  @Mock private RoutineRepository routineRepository;
  @InjectMocks private RoutineMemoryService service;

  @BeforeEach
  void setUp() {
    Profile profile = new Profile();
    profile.setId(PROFILE_ID);
    org.mockito.Mockito.lenient().when(profileAccessGuard.profileFor(GUARDIAN, ProfileAction.MANAGE)).thenReturn(profile);
    org.mockito.Mockito.lenient().when(entitlementService.isAllowed("member-a", Entitlement.ROUTINE_MEMORY)).thenReturn(true);
  }

  private static RoutineMemoryRule aiRule(RoutineMemoryRuleStatus status) {
    RoutineMemoryRule rule = new RoutineMemoryRule();
    rule.setId("rule-1");
    rule.setProfileId(PROFILE_ID);
    rule.setMemberId("member-a");
    rule.setType(RoutineMemoryRuleType.WORD);
    rule.setStatus(status);
    rule.setSource(RoutineMemoryRuleSource.AI);
    rule.setSummary("착용해요 대신 입어요");
    rule.setBeforeText("착용해요");
    rule.setAfterText("입어요");
    return rule;
  }

  private static RoutineMemoryRule manualRule() {
    RoutineMemoryRule rule = aiRule(RoutineMemoryRuleStatus.ACTIVE);
    rule.setType(RoutineMemoryRuleType.MANUAL);
    rule.setSource(RoutineMemoryRuleSource.MANUAL);
    rule.setBeforeText(null);
    rule.setAfterText(null);
    rule.setSummary("카드 글은 10자 안으로");
    return rule;
  }

  private static ErrorCode errorCodeOf(Throwable thrown) {
    return ((CustomException) thrown).getErrorCode();
  }

  // --- 보기 ---

  @Test
  @DisplayName("Free 는 빈 응답(available=false)을 받고 규칙을 조회하지 않는다 — 미리 보기 판이 규칙을 보여 준다")
  void get_free_isUnavailable() {
    when(entitlementService.isAllowed("member-a", Entitlement.ROUTINE_MEMORY)).thenReturn(false);
    when(policy.autoApplyCount()).thenReturn(3);

    RoutineMemoryResponse response = service.get(GUARDIAN);

    assertThat(response.available()).isFalse();
    assertThat(response.rules()).isEmpty();
    verify(assembler, never()).assemble(anyString(), anyString());
  }

  // --- 직접 적기 ---

  @Test
  @DisplayName("직접 적은 글에 진단·장애 표현이 있으면 400 ROUTINE_MEMORY_LINE_NOT_ALLOWED 로 저장하지 않는다")
  void addRule_forbiddenText_rejected() {
    assertThatThrownBy(() -> service.addRule(GUARDIAN, "자폐라서 카드는 짧게"))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.ROUTINE_MEMORY_LINE_NOT_ALLOWED));
    verify(ruleRepository, never()).save(any());
  }

  @Test
  @DisplayName("빈 글·60자 넘는 글은 400 INVALID_INPUT_VALUE")
  void addRule_blankOrTooLong_rejected() {
    assertThatThrownBy(() -> service.addRule(GUARDIAN, "  "))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    assertThatThrownBy(() -> service.addRule(GUARDIAN, "가".repeat(61)))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("직접 적은 규칙은 MANUAL·ACTIVE 로 저장한다")
  void addRule_savesManualActive() {
    when(ruleRepository.findAllByProfileIdAndMemberId(PROFILE_ID, "member-a")).thenReturn(List.of());

    service.addRule(GUARDIAN, "카드 글은 10자 안으로");

    ArgumentCaptor<RoutineMemoryRule> saved = ArgumentCaptor.forClass(RoutineMemoryRule.class);
    verify(ruleRepository).save(saved.capture());
    assertThat(saved.getValue().getType()).isEqualTo(RoutineMemoryRuleType.MANUAL);
    assertThat(saved.getValue().getStatus()).isEqualTo(RoutineMemoryRuleStatus.ACTIVE);
    assertThat(saved.getValue().getSource()).isEqualTo(RoutineMemoryRuleSource.MANUAL);
    assertThat(saved.getValue().getMemberId()).isEqualTo("member-a");
  }

  // --- 고치기 ---

  @Test
  @DisplayName("관찰 중 규칙을 ACTIVE 로 바꾸면 횟수와 상관없이 적용된다 (항상 이렇게 / 지금 적용)")
  void updateRule_watchingToActive() {
    RoutineMemoryRule rule = aiRule(RoutineMemoryRuleStatus.WATCHING);
    when(ruleRepository.findByIdAndProfileIdAndMemberId("rule-1", PROFILE_ID, "member-a")).thenReturn(Optional.of(rule));

    service.updateRule(GUARDIAN, "rule-1", new RoutineMemoryRuleUpdateRequest(RoutineMemoryRuleStatus.ACTIVE, null));

    assertThat(rule.getStatus()).isEqualTo(RoutineMemoryRuleStatus.ACTIVE);
  }

  @Test
  @DisplayName("WATCHING 으로 되돌리거나 값 없이 고치려 하면 400 — 보호자가 임의로 관찰 중으로 못 바꾼다")
  void updateRule_invalidRequests_rejected() {
    assertThatThrownBy(() -> service.updateRule(GUARDIAN, "rule-1",
      new RoutineMemoryRuleUpdateRequest(RoutineMemoryRuleStatus.WATCHING, null)))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    assertThatThrownBy(() -> service.updateRule(GUARDIAN, "rule-1", new RoutineMemoryRuleUpdateRequest(null, null)))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("남의 규칙 id 로 고치면 400 — 다른 보호자의 규칙을 건드린다")
  void updateRule_otherGuardiansRule_rejected() {
    when(ruleRepository.findByIdAndProfileIdAndMemberId("rule-9", PROFILE_ID, "member-a")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.updateRule(GUARDIAN, "rule-9",
      new RoutineMemoryRuleUpdateRequest(RoutineMemoryRuleStatus.OFF, null)))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("글 고치기는 직접 적은 규칙만 된다 — AI 가 찾은 규칙의 낱말이 임의로 바뀐다")
  void updateRule_textOnlyForManualRules() {
    RoutineMemoryRule aiRule = aiRule(RoutineMemoryRuleStatus.ACTIVE);
    when(ruleRepository.findByIdAndProfileIdAndMemberId("rule-1", PROFILE_ID, "member-a")).thenReturn(Optional.of(aiRule));
    assertThatThrownBy(() -> service.updateRule(GUARDIAN, "rule-1", new RoutineMemoryRuleUpdateRequest(null, "새 글")))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));

    RoutineMemoryRule manual = manualRule();
    when(ruleRepository.findByIdAndProfileIdAndMemberId("rule-1", PROFILE_ID, "member-a")).thenReturn(Optional.of(manual));
    service.updateRule(GUARDIAN, "rule-1", new RoutineMemoryRuleUpdateRequest(null, "카드 글은 8자 안으로"));
    assertThat(manual.getSummary()).isEqualTo("카드 글은 8자 안으로");
    assertThatThrownBy(() -> service.updateRule(GUARDIAN, "rule-1", new RoutineMemoryRuleUpdateRequest(null, "치료 얘기 빼요")))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.ROUTINE_MEMORY_LINE_NOT_ALLOWED));
  }

  // --- 지우기 ---

  @Test
  @DisplayName("AI 규칙을 지우면 근거를 지우고 같은 수정을 거절 기억에 남긴다 — 지운 규칙이 AI 재관찰로 되살아난다")
  void deleteRule_remembersRejection() {
    RoutineMemoryRule rule = aiRule(RoutineMemoryRuleStatus.ACTIVE);
    when(ruleRepository.findByIdAndProfileIdAndMemberId("rule-1", PROFILE_ID, "member-a")).thenReturn(Optional.of(rule));
    when(rejectionRepository.findAllByProfileIdAndMemberId(PROFILE_ID, "member-a")).thenReturn(List.of());

    service.deleteRule(GUARDIAN, "rule-1");

    ArgumentCaptor<RoutineMemoryRejection> rejection = ArgumentCaptor.forClass(RoutineMemoryRejection.class);
    verify(rejectionRepository).save(rejection.capture());
    assertThat(rejection.getValue().getType()).isEqualTo(RoutineMemoryRuleType.WORD);
    assertThat(rejection.getValue().getBeforeText()).isEqualTo("착용해요");
    assertThat(rejection.getValue().getAfterText()).isEqualTo("입어요");
    verify(evidenceRepository).deleteAllByRuleIds(List.of("rule-1"));
    verify(ruleRepository).delete(rule);
  }

  @Test
  @DisplayName("직접 적은 규칙을 지울 때는 거절 기억을 남기지 않는다")
  void deleteRule_manual_noRejection() {
    RoutineMemoryRule manual = manualRule();
    when(ruleRepository.findByIdAndProfileIdAndMemberId("rule-1", PROFILE_ID, "member-a")).thenReturn(Optional.of(manual));

    service.deleteRule(GUARDIAN, "rule-1");

    verify(rejectionRepository, never()).save(any());
    verify(ruleRepository).delete(manual);
  }

  // --- 켜기/끄기·모두 지우기·나갈 때 지우기 ---

  @Test
  @DisplayName("끄기 값이 없으면 400, 있으면 (이룸이, 보호자) 설정에 저장한다")
  void setEnabled_requiresValue() {
    assertThatThrownBy(() -> service.setEnabled(GUARDIAN, null))
      .satisfies(thrown -> assertThat(errorCodeOf(thrown)).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));

    service.setEnabled(GUARDIAN, false);

    verify(settings).setEnabled(PROFILE_ID, "member-a", false);
  }

  @Test
  @DisplayName("모두 지우기는 규칙·근거·수정 기록·거절 기억과 이 보호자 일과의 AI 처음 카드 사본 표시를 지운다")
  void clear_deletesEverythingOfOwner() {
    service.clear(GUARDIAN);

    verify(evidenceRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(ruleRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(editRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(rejectionRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(routineRepository).clearAiDraftCardsOfOwner(eq(PROFILE_ID), eq("member-a"), any());
    verify(settingRepository, never()).deleteAllByOwner(anyString(), anyString());
  }

  @Test
  @DisplayName("보호자가 이룸이에서 나가면 그 (이룸이, 보호자)의 메모리와 설정을 모두 지운다 — 나간 보호자의 규칙이 남는다")
  void forgetMember_deletesOnlyThatOwnersRows() {
    service.forgetMember(PROFILE_ID, "member-a");

    verify(evidenceRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(ruleRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(editRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(rejectionRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(settingRepository).deleteAllByOwner(PROFILE_ID, "member-a");
    verify(ruleRepository, never()).deleteAllByOwner(eq(PROFILE_ID), eq("member-b"));
  }
}
