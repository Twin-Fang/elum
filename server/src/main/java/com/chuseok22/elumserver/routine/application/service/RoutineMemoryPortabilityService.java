package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryImportRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryImportRequest.ImportedRule;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryExportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryExportResponse.ExportedRule;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryImportResponse;
import com.chuseok22.elumserver.routine.core.RoutineMemoryFindingValidator;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.chuseok22.elumserver.routine.core.RoutineMemorySafetyFilter;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * AI 메모리 내보내기·가져오기: 규칙만 (이룸이 이름·회원 식별값·근거 일과 제목 없음)
 * 가져오기는 병합: 같은 (종류, before, after, 요약) 건너뜀 > 필터·형식에 걸리면 버림 > WATCHING 은 근거 0 으로 시작
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineMemoryPortabilityService {

  /// 한 번에 가져올 수 있는 규칙 수
  static final int MAX_IMPORT_RULES = 200;

  private final ProfileAccessGuard profileAccessGuard;
  private final EntitlementService entitlementService;
  private final RoutineMemoryRuleRepository routineMemoryRuleRepository;

  public RoutineMemoryExportResponse export(Caller caller) {
    Profile profile = requireAvailableProfile(caller);
    List<ExportedRule> rules = routineMemoryRuleRepository.findAllByProfileIdAndMemberId(profile.getId(), caller.memberId())
      .stream()
      .map(rule -> new ExportedRule(rule.getType(), rule.getStatus(), rule.getSource(), rule.getSummary(),
        rule.getBeforeText(), rule.getAfterText()))
      .toList();
    return new RoutineMemoryExportResponse(RoutineMemoryExportResponse.SCHEMA, OffsetDateTime.now(), rules);
  }

  /// 가져오기: 권한 > schema 확인(모르면 400) > 규칙마다 검증·중복 확인 > 저장 > 개수 보고
  @Transactional
  public RoutineMemoryImportResponse importRules(Caller caller, RoutineMemoryImportRequest request) {
    Profile profile = requireAvailableProfile(caller);
    if (request == null || !RoutineMemoryExportResponse.SCHEMA.equals(request.schema()) || request.rules() == null
      || request.rules().size() > MAX_IMPORT_RULES) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<RoutineMemoryRule> ownedRules = routineMemoryRuleRepository.findAllByProfileIdAndMemberId(
      profile.getId(), caller.memberId());
    Set<String> knownKeys = new HashSet<>();
    ownedRules.forEach(rule -> knownKeys.add(duplicateKey(rule.getType(), rule.getBeforeText(), rule.getAfterText(),
      rule.getSummary())));
    int ruleCount = ownedRules.size();
    int manualCount = (int) ownedRules.stream().filter(rule -> rule.getType() == RoutineMemoryRuleType.MANUAL).count();

    int importedCount = 0;
    int duplicateCount = 0;
    int rejectedCount = 0;
    for (ImportedRule importedRule : request.rules()) {
      RoutineMemoryRule rule = toRule(importedRule, profile.getId(), caller.memberId());
      if (rule == null) {
        rejectedCount++;
        continue;
      }
      boolean isManual = rule.getType() == RoutineMemoryRuleType.MANUAL;
      boolean isOverLimit = ruleCount >= RoutineMemoryPolicy.MAX_RULES_PER_OWNER
        || (isManual && manualCount >= RoutineMemoryPolicy.MAX_MANUAL_RULES_PER_OWNER);
      if (isOverLimit) {
        rejectedCount++;
      } else if (!knownKeys.add(duplicateKey(rule.getType(), rule.getBeforeText(), rule.getAfterText(), rule.getSummary()))) {
        duplicateCount++;
      } else {
        routineMemoryRuleRepository.save(rule);
        importedCount++;
        ruleCount++;
        manualCount += isManual ? 1 : 0;
      }
    }
    log.info("[routine memory] import done : profileId={}, imported={}, duplicate={}, rejected={}", profile.getId(),
      importedCount, duplicateCount, rejectedCount);
    return new RoutineMemoryImportResponse(importedCount, duplicateCount, rejectedCount);
  }

  /// 파일 한 건 > 규칙. 알 수 없는 값·형식 위반·금지어면 null. 종류 MANUAL 은 직접 적음, 그 밖은 AI 출처 (근거 0)
  private static RoutineMemoryRule toRule(ImportedRule imported, String profileId, String memberId) {
    RoutineMemoryRuleType type = parseEnum(RoutineMemoryRuleType.class, imported.type());
    RoutineMemoryRuleStatus status = imported.status() == null
      ? null : parseEnum(RoutineMemoryRuleStatus.class, imported.status());
    if (type == null || (imported.status() != null && status == null) || !isAllowedText(imported.summary())
      || !hasRequiredTexts(type, imported.before(), imported.after())) {
      return null;
    }
    boolean isManual = type == RoutineMemoryRuleType.MANUAL;
    RoutineMemoryRule rule = new RoutineMemoryRule();
    rule.setProfileId(profileId);
    rule.setMemberId(memberId);
    rule.setType(type);
    rule.setSource(isManual ? RoutineMemoryRuleSource.MANUAL : RoutineMemoryRuleSource.AI);
    rule.setStatus(statusOf(status, isManual));
    rule.setSummary(imported.summary().trim());
    rule.setBeforeText(isManual ? null : blankToNull(imported.before()));
    rule.setAfterText(isManual ? null : blankToNull(imported.after()));
    rule.setEvidenceCount(0);
    return rule;
  }

  /// 값이 없으면 직접 적은 규칙은 ACTIVE, AI 규칙은 WATCHING. 직접 적은 규칙은 관찰 중이 없어 ACTIVE
  private static RoutineMemoryRuleStatus statusOf(RoutineMemoryRuleStatus status, boolean isManual) {
    if (status == null) {
      return isManual ? RoutineMemoryRuleStatus.ACTIVE : RoutineMemoryRuleStatus.WATCHING;
    }
    return isManual && status == RoutineMemoryRuleStatus.WATCHING ? RoutineMemoryRuleStatus.ACTIVE : status;
  }

  private static boolean hasRequiredTexts(RoutineMemoryRuleType type, String before, String after) {
    boolean hasBefore = before != null && !before.isBlank();
    boolean hasAfter = after != null && !after.isBlank();
    boolean isStructureValid = switch (type) {
      case WORD, SPLIT, MERGE -> hasBefore && hasAfter;
      case ADD -> hasAfter;
      case REMOVE -> hasBefore;
      case MANUAL -> true;
    };
    return isStructureValid && (!hasBefore || isAllowedText(before)) && (!hasAfter || isAllowedText(after));
  }

  private static boolean isAllowedText(String text) {
    return text != null && !text.isBlank() && text.trim().length() <= RoutineMemoryFindingValidator.MAX_TEXT_LENGTH
      && RoutineMemorySafetyFilter.isAllowed(text.trim()) && !RoutineMemorySafetyFilter.hasForbiddenTermOrContact(text);
  }

  private static String duplicateKey(RoutineMemoryRuleType type, String before, String after, String summary) {
    return type + "\n" + normalize(before) + "\n" + normalize(after) + "\n" + normalize(summary);
  }

  private static String normalize(String text) {
    return Objects.toString(text, "").trim().toLowerCase(Locale.ROOT);
  }

  private static String blankToNull(String text) {
    return text == null || text.isBlank() ? null : text.trim();
  }

  private static <E extends Enum<E>> E parseEnum(Class<E> type, String text) {
    if (text == null) {
      return null;
    }
    try {
      return Enum.valueOf(type, text.trim().toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException e) {
      return null;
    }
  }

  private Profile requireAvailableProfile(Caller caller) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    entitlementService.requireAllowed(caller.memberId(), Entitlement.ROUTINE_MEMORY);
    return profile;
  }
}
