package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryObservationResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryObservationResponse.Item;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryObservationResponse.Status;
import com.chuseok22.elumserver.routine.core.RoutineMemoryExtractionState;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEdit;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEvidence;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEditRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEvidenceRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 방금 고쳐서 보낸 일과에서 찾은 수정 보기: 일과 확인(내 이룸이·내가 만든 일과) > 찾기 진행(PENDING/DONE/없음) > 근거로 잡힌 규칙
 * 대상이 아니거나 남의 일과면 NONE (존재 여부를 알려 주지 않음). 꺼 둔 규칙(OFF)은 "다음에도?"를 묻지 않아 뺌
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineMemoryObservationService {

  private final ProfileAccessGuard profileAccessGuard;
  private final EntitlementService entitlementService;
  private final RoutineRepository routineRepository;
  private final RoutineMemoryEditRepository routineMemoryEditRepository;
  private final RoutineMemoryEvidenceRepository routineMemoryEvidenceRepository;
  private final RoutineMemoryRuleRepository routineMemoryRuleRepository;
  private final RoutineMemorySettings routineMemorySettings;

  public RoutineMemoryObservationResponse observationsOf(Caller caller, String routineId) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    String memberId = caller.memberId();
    Optional<Routine> routine = routineRepository.findById(routineId)
      .filter(found -> found.getProfile() != null && profile.getId().equals(found.getProfile().getId())
        && memberId.equals(found.getCreatedBy()));
    if (routine.isEmpty() || !entitlementService.isAllowed(memberId, Entitlement.ROUTINE_MEMORY)) {
      return RoutineMemoryObservationResponse.of(Status.NONE);
    }
    Optional<RoutineMemoryEdit> edit = routineMemoryEditRepository.findByRoutineId(routineId);
    if (edit.isEmpty()) {
      return RoutineMemoryObservationResponse.of(isWaitingForClaim(routine.get(), profile.getId(), memberId)
        ? Status.PENDING : Status.NONE);
    }
    if (edit.get().getExtractionState() == RoutineMemoryExtractionState.PENDING) {
      return RoutineMemoryObservationResponse.of(Status.PENDING);
    }
    if (edit.get().getExtractionState() == RoutineMemoryExtractionState.FAILED) {
      return RoutineMemoryObservationResponse.of(Status.NONE);
    }
    List<Item> items = itemsOf(routineId, profile.getId(), memberId);
    return items.isEmpty()
      ? RoutineMemoryObservationResponse.of(Status.NONE)
      : new RoutineMemoryObservationResponse(Status.READY, items);
  }

  /// 아직 아무도 선점하지 않은 AI 일과 (확정됨 + 처음 카드 사본 있음 + 반영 표시 없음 + 켜짐)
  private boolean isWaitingForClaim(Routine routine, String profileId, String memberId) {
    boolean isConfirmed = routine.getStatus() == RoutineStatus.CONFIRMED
      || routine.getStatus() == RoutineStatus.COMPLETED;
    return isConfirmed && routine.getAiDraftCards() != null && routine.getMemoryReflectedAt() == null
      && routineMemorySettings.isEnabled(profileId, memberId);
  }

  private List<Item> itemsOf(String routineId, String profileId, String memberId) {
    List<String> ruleIds = routineMemoryEvidenceRepository.findAllByRoutineId(routineId).stream()
      .map(RoutineMemoryEvidence::getRuleId)
      .toList();
    if (ruleIds.isEmpty()) {
      return List.of();
    }
    return routineMemoryRuleRepository.findAllByIdInAndProfileIdAndMemberId(ruleIds, profileId, memberId).stream()
      .filter(rule -> rule.getStatus() != RoutineMemoryRuleStatus.OFF)
      .map(RoutineMemoryObservationService::toItem)
      .toList();
  }

  private static Item toItem(RoutineMemoryRule rule) {
    return new Item(rule.getId(), rule.getType(), rule.getSummary(), rule.getBeforeText(), rule.getAfterText(),
      rule.getEvidenceCount(), rule.getStatus());
  }
}
