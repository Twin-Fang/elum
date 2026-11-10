package com.chuseok22.elumserver.routine.application.service;

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
import com.chuseok22.elumserver.routine.core.RoutineMemoryFinding;
import com.chuseok22.elumserver.routine.core.RoutineMemoryFindingValidator;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.chuseok22.elumserver.routine.core.RoutineMemorySafetyFilter;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRejection;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEditRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEvidenceRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRejectionRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemorySettingRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 보호자의 AI 메모리 관리: 보기, 직접 적기, 규칙 켜기·끄기·글 고치기, 지우기(거절 기억), 켜기/끄기, 모두 지우기, 나갈 때 지우기
 * 메모리는 (이룸이, 보호자) 한 쌍의 것 — 다른 보호자의 규칙은 보지도 고치지도 못함. 권한: 이룸이 MANAGE + Pro(ROUTINE_MEMORY), Free 는 보기만(빈 응답)
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineMemoryService {

  private final ProfileAccessGuard profileAccessGuard;
  private final EntitlementService entitlementService;
  private final RoutineMemoryRuleRepository routineMemoryRuleRepository;
  private final RoutineMemoryEvidenceRepository routineMemoryEvidenceRepository;
  private final RoutineMemoryEditRepository routineMemoryEditRepository;
  private final RoutineMemoryRejectionRepository routineMemoryRejectionRepository;
  private final RoutineMemorySettingRepository routineMemorySettingRepository;
  private final RoutineMemorySettings routineMemorySettings;
  private final RoutineMemoryResponseAssembler routineMemoryResponseAssembler;
  private final RoutineMemoryPolicy routineMemoryPolicy;
  private final RoutineRepository routineRepository;

  /// 보기: Free > 빈 응답(available=false) / 행 없음 > 켜짐·빈 목록
  public RoutineMemoryResponse get(Caller caller) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    if (!entitlementService.isAllowed(caller.memberId(), Entitlement.ROUTINE_MEMORY)) {
      return RoutineMemoryResponse.unavailable(routineMemoryPolicy.autoApplyCount());
    }
    return routineMemoryResponseAssembler.assemble(profile.getId(), caller.memberId());
  }

  /// 직접 적기: 권한 > 글 검증(60자·금지 낱말) > 상한 > 같은 글이면 그대로 > 저장(MANUAL, ACTIVE)
  @Transactional
  public RoutineMemoryResponse addRule(Caller caller, String text) {
    Profile profile = requireAvailableProfile(caller);
    String memberId = caller.memberId();
    String summary = validatedRuleText(text);
    List<RoutineMemoryRule> ownedRules = routineMemoryRuleRepository.findAllByProfileIdAndMemberId(profile.getId(), memberId);
    boolean isDuplicate = ownedRules.stream()
      .anyMatch(rule -> rule.getType() == RoutineMemoryRuleType.MANUAL && rule.getSummary().equalsIgnoreCase(summary));
    long manualCount = ownedRules.stream().filter(rule -> rule.getType() == RoutineMemoryRuleType.MANUAL).count();
    if (manualCount >= RoutineMemoryPolicy.MAX_MANUAL_RULES_PER_OWNER) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    if (!isDuplicate) {
      RoutineMemoryRule rule = new RoutineMemoryRule();
      rule.setProfileId(profile.getId());
      rule.setMemberId(memberId);
      rule.setType(RoutineMemoryRuleType.MANUAL);
      rule.setStatus(RoutineMemoryRuleStatus.ACTIVE);
      rule.setSource(RoutineMemoryRuleSource.MANUAL);
      rule.setSummary(summary);
      routineMemoryRuleRepository.save(rule);
      log.info("[routine memory] rule added : profileId={}, type=MANUAL", profile.getId());
    }
    return routineMemoryResponseAssembler.assemble(profile.getId(), memberId);
  }

  /// 규칙 고치기: status(ACTIVE | OFF) 또는 text(직접 적은 규칙만). 관찰 중 > 적용이 "항상 이렇게 / 지금 적용"
  @Transactional
  public RoutineMemoryResponse updateRule(Caller caller, String ruleId, RoutineMemoryRuleUpdateRequest request) {
    Profile profile = requireAvailableProfile(caller);
    if (request == null || (request.status() == null && request.text() == null)
      || request.status() == RoutineMemoryRuleStatus.WATCHING) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    RoutineMemoryRule rule = findOwnedRule(profile.getId(), caller.memberId(), ruleId);
    if (request.text() != null) {
      boolean isManualRule = rule.getType() == RoutineMemoryRuleType.MANUAL
        && rule.getSource() == RoutineMemoryRuleSource.MANUAL;
      if (!isManualRule) {
        throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
      }
      rule.setSummary(validatedRuleText(request.text()));
    }
    if (request.status() != null) {
      log.info("[routine memory] rule status changed : profileId={}, {} -> {}", profile.getId(), rule.getStatus(),
        request.status());
      rule.setStatus(request.status());
    }
    return routineMemoryResponseAssembler.assemble(profile.getId(), caller.memberId());
  }

  /// 지우기: 규칙·근거 삭제 > AI 규칙이면 같은 수정을 다시 가져와도 되살리지 않게 거절 기억
  @Transactional
  public RoutineMemoryResponse deleteRule(Caller caller, String ruleId) {
    Profile profile = requireAvailableProfile(caller);
    String memberId = caller.memberId();
    RoutineMemoryRule rule = findOwnedRule(profile.getId(), memberId, ruleId);
    if (rule.getType() != RoutineMemoryRuleType.MANUAL) {
      rememberRejection(profile.getId(), memberId, rule);
    }
    routineMemoryEvidenceRepository.deleteAllByRuleIds(List.of(rule.getId()));
    routineMemoryRuleRepository.delete(rule);
    log.info("[routine memory] rule deleted : profileId={}, type={}", profile.getId(), rule.getType());
    return routineMemoryResponseAssembler.assemble(profile.getId(), memberId);
  }

  /// 켜기/끄기. 끄면 수정을 찾지도 일과 만들기에 넣지도 않음 (규칙은 남음)
  @Transactional
  public RoutineMemoryResponse setEnabled(Caller caller, Boolean isEnabled) {
    if (isEnabled == null) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    Profile profile = requireAvailableProfile(caller);
    routineMemorySettings.setEnabled(profile.getId(), caller.memberId(), isEnabled);
    log.info("[routine memory] enabled changed : profileId={}, enabled={}", profile.getId(), isEnabled);
    return routineMemoryResponseAssembler.assemble(profile.getId(), caller.memberId());
  }

  /// 모두 지우기: 규칙·근거·수정 기록·거절 기억 + 이 보호자 일과의 AI 처음 카드 사본 표시. 켜짐 상태는 그대로
  @Transactional
  public RoutineMemoryResponse clear(Caller caller) {
    Profile profile = requireAvailableProfile(caller);
    String memberId = caller.memberId();
    int deletedRuleCount = deleteOwnedRows(profile.getId(), memberId);
    int clearedRoutineCount = routineRepository.clearAiDraftCardsOfOwner(profile.getId(), memberId, LocalDateTime.now());
    log.info("[routine memory] cleared : profileId={}, rules={}, clearedRoutines={}", profile.getId(), deletedRuleCount,
      clearedRoutineCount);
    return routineMemoryResponseAssembler.assemble(profile.getId(), memberId);
  }

  /// 보호자가 이룸이에서 나감(탈퇴·이룸이 삭제 포함): 그 (이룸이, 보호자)의 메모리 전부 + 켜짐 설정 (부르는 쪽 트랜잭션)
  @Transactional
  public void forgetMember(String profileId, String memberId) {
    int deletedRuleCount = deleteOwnedRows(profileId, memberId);
    int deletedSettingCount = routineMemorySettingRepository.deleteAllByOwner(profileId, memberId);
    if (deletedRuleCount > 0 || deletedSettingCount > 0) {
      log.info("[routine memory] forgotten : profileId={}, rules={}", profileId, deletedRuleCount);
    }
  }

  /// 근거 > 규칙 > 수정 기록 > 거절 기억 순으로 지움. 지운 규칙 수
  private int deleteOwnedRows(String profileId, String memberId) {
    routineMemoryEvidenceRepository.deleteAllByOwner(profileId, memberId);
    int deletedRuleCount = routineMemoryRuleRepository.deleteAllByOwner(profileId, memberId);
    routineMemoryEditRepository.deleteAllByOwner(profileId, memberId);
    routineMemoryRejectionRepository.deleteAllByOwner(profileId, memberId);
    return deletedRuleCount;
  }

  private void rememberRejection(String profileId, String memberId, RoutineMemoryRule rule) {
    String ruleKey = RoutineMemoryFinding.identityKeyOf(rule.getType(), rule.getBeforeText(), rule.getAfterText());
    boolean isAlreadyRemembered = routineMemoryRejectionRepository.findAllByProfileIdAndMemberId(profileId, memberId)
      .stream()
      .anyMatch(rejection -> ruleKey.equals(
        RoutineMemoryFinding.identityKeyOf(rejection.getType(), rejection.getBeforeText(), rejection.getAfterText())));
    if (isAlreadyRemembered) {
      return;
    }
    RoutineMemoryRejection rejection = new RoutineMemoryRejection();
    rejection.setProfileId(profileId);
    rejection.setMemberId(memberId);
    rejection.setType(rule.getType());
    rejection.setBeforeText(rule.getBeforeText());
    rejection.setAfterText(rule.getAfterText());
    routineMemoryRejectionRepository.save(rejection);
  }

  private RoutineMemoryRule findOwnedRule(String profileId, String memberId, String ruleId) {
    return routineMemoryRuleRepository.findByIdAndProfileIdAndMemberId(ruleId, profileId, memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.INVALID_INPUT_VALUE));
  }

  /// 규칙 글 검증: 빈 글·60자 넘음 > 400 / 진단·장애·정도·연락처·기관 이름 > 400 ROUTINE_MEMORY_LINE_NOT_ALLOWED
  static String validatedRuleText(String text) {
    if (text == null || text.isBlank() || text.trim().length() > RoutineMemoryFindingValidator.MAX_TEXT_LENGTH) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    String trimmed = text.trim();
    if (!RoutineMemorySafetyFilter.isAllowed(trimmed) || RoutineMemorySafetyFilter.hasForbiddenTermOrContact(trimmed)) {
      throw new CustomException(ErrorCode.ROUTINE_MEMORY_LINE_NOT_ALLOWED);
    }
    return trimmed;
  }

  private Profile requireAvailableProfile(Caller caller) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    entitlementService.requireAllowed(caller.memberId(), Entitlement.ROUTINE_MEMORY);
    return profile;
  }
}
