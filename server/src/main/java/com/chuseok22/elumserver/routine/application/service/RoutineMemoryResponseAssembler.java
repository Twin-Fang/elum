package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse.EditResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse.EvidenceResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse.RuleResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEvidence;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEditRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEvidenceRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

/// 화면용 AI 메모리 응답 조립: 규칙(ACTIVE, WATCHING, OFF 순 > 최근 먼저) + 규칙마다 근거 5개 + 수정 기록 20개
@Component
@RequiredArgsConstructor
public class RoutineMemoryResponseAssembler {

  private final RoutineMemoryRuleRepository routineMemoryRuleRepository;
  private final RoutineMemoryEvidenceRepository routineMemoryEvidenceRepository;
  private final RoutineMemoryEditRepository routineMemoryEditRepository;
  private final RoutineMemorySettings routineMemorySettings;
  private final RoutineMemoryPolicy routineMemoryPolicy;

  public RoutineMemoryResponse assemble(String profileId, String memberId) {
    List<RoutineMemoryRule> rules = routineMemoryRuleRepository.findAllByProfileIdAndMemberId(profileId, memberId)
      .stream()
      .sorted(Comparator.comparingInt((RoutineMemoryRule rule) -> rule.getStatus().ordinal())
        .thenComparing(RoutineMemoryRule::getUpdatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
      .toList();
    Map<String, List<EvidenceResponse>> evidencesByRuleId = evidencesByRuleId(rules);
    List<RuleResponse> ruleResponses = rules.stream()
      .map(rule -> toRuleResponse(rule, evidencesByRuleId.getOrDefault(rule.getId(), List.of())))
      .toList();
    List<EditResponse> editResponses = routineMemoryEditRepository
      .findAllByProfileIdAndMemberIdOrderByEditedAtDesc(
        profileId, memberId, PageRequest.of(0, RoutineMemoryPolicy.MAX_EDITS_SHOWN))
      .stream()
      .map(edit -> new EditResponse(edit.getRoutineTitle(), edit.getEditedAt().toLocalDate(),
        edit.getCardCountBefore(), edit.getCardCountAfter(), edit.getChangedTextCount()))
      .toList();
    return new RoutineMemoryResponse(true, routineMemorySettings.isEnabled(profileId, memberId),
      routineMemoryPolicy.autoApplyCount(), ruleResponses, editResponses);
  }

  /// 근거 한 번에 읽기 (최근 관찰 먼저, 규칙마다 5개까지)
  private Map<String, List<EvidenceResponse>> evidencesByRuleId(List<RoutineMemoryRule> rules) {
    if (rules.isEmpty()) {
      return Map.of();
    }
    Map<String, List<EvidenceResponse>> evidencesByRuleId = new HashMap<>();
    List<RoutineMemoryEvidence> evidences = routineMemoryEvidenceRepository.findAllByRuleIdInOrderByObservedAtDesc(
      rules.stream().map(RoutineMemoryRule::getId).toList());
    for (RoutineMemoryEvidence evidence : evidences) {
      List<EvidenceResponse> shown = evidencesByRuleId.computeIfAbsent(evidence.getRuleId(), id -> new ArrayList<>());
      if (shown.size() < RoutineMemoryPolicy.MAX_EVIDENCES_SHOWN) {
        shown.add(new EvidenceResponse(evidence.getRoutineTitle(), evidence.getObservedAt().toLocalDate()));
      }
    }
    return evidencesByRuleId;
  }

  private static RuleResponse toRuleResponse(RoutineMemoryRule rule, List<EvidenceResponse> evidences) {
    LocalDateTime updatedAt = rule.getUpdatedAt() == null ? LocalDateTime.now() : rule.getUpdatedAt();
    return new RuleResponse(rule.getId(), rule.getType(), rule.getStatus(), rule.getSource(), rule.getSummary(),
      rule.getBeforeText(), rule.getAfterText(), rule.getEvidenceCount(), evidences,
      updatedAt.atZone(ZoneId.systemDefault()).toOffsetDateTime());
  }
}
