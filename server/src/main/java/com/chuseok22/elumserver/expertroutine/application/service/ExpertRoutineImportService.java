package com.chuseok22.elumserver.expertroutine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineImportRequest;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineImportResponse;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineRepository;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft.DraftStep;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 전문가 일과 가져오기: Pro 권한 확인, 보이는 일과 확인, 일과관리 원본 만들기(일과 쪽, AI·크레딧 없음), 가져간 횟수
 * 가져간 일과는 이야기 글과 달리 원본 취급 (talkPostId 없음 > 이야기·링크로 다시 나눌 수 있음)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ExpertRoutineImportService {

  private final ExpertRoutineQueryService expertRoutineQueryService;
  private final ExpertRoutineRepository expertRoutineRepository;
  private final EntitlementService entitlementService;
  private final RoutineShareService routineShareService;

  /**
   * 가져오기: 요청 검증 > Pro 권한 > 보이는 일과 > 초안 > 일과 만들기 위임 > 횟수 +1
   *
   * @throws CustomException 이룸이 없음 INVALID_INPUT_VALUE, Free EXPERT_ROUTINE_PRO_ONLY, 내린 일과 EXPERT_ROUTINE_NOT_FOUND,
   *                         이룸이·묶음 오류는 일과 쪽 예외 그대로
   */
  @Transactional
  public ExpertRoutineImportResponse importToLibrary(
    Caller caller, String expertRoutineId, ExpertRoutineImportRequest request
  ) {
    if (request == null || request.profileId() == null || request.profileId().isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    if (!entitlementService.isAllowed(caller.memberId(), Entitlement.ROUTINE_TEMPLATES)) {
      log.info("[expert routine import] rejected 403 : plan has no routine templates");
      throw new CustomException(ErrorCode.EXPERT_ROUTINE_PRO_ONLY);
    }
    ExpertRoutine expertRoutine = expertRoutineQueryService.requireVisible(expertRoutineId);

    RoutineImportDraft draft = toDraft(expertRoutine, expertRoutineQueryService.stepsOf(expertRoutine.getId()));
    String routineId = routineShareService.importToLibrary(caller, request.profileId(), request.groupId(), draft);
    expertRoutineRepository.increaseImportCount(expertRoutine.getId());
    log.info("[expert routine import] imported : expertRoutineId={}, stepCount={}",
      expertRoutine.getId(), draft.steps().size());
    return new ExpertRoutineImportResponse(routineId, request.profileId());
  }

  // 카드 문장 > 카드 제목·설명 둘 다 (예시 일과와 같은 모양), 그림은 번들 id 만
  private static RoutineImportDraft toDraft(ExpertRoutine expertRoutine, List<ExpertRoutineStep> steps) {
    List<DraftStep> draftSteps = steps.stream()
      .map(step -> new DraftStep(step.getStepOrder(), step.getText(), step.getText(),
        step.getPictogramId(), step.getExampleImageId(), null))
      .toList();
    return new RoutineImportDraft(null, expertRoutine.getTitle(), expertRoutine.getLanguage(), draftSteps,
      expertRoutine.getRewardText(), expertRoutine.getRewardPresetKey());
  }
}
