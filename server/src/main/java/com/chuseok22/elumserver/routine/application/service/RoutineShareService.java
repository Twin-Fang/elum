package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot.StepSnapshot;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기 공유용 일과 읽기: 권한 확인, 오늘 일과 > 원본 변환, 공유 불가 판정, 카드 스냅샷, 그림 읽기
 * 일과·그림 저장소를 직접 쓰는 곳은 이 서비스뿐 (talk 는 여기만 거침, 쓰기 없음)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineShareService {

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineImageStorage routineImageStorage;

  /**
   * 공유할 일과 스냅샷: 권한 확인 > 원본 찾기(오늘 일과면 sourceRoutineId) > 공유 불가 거절 > 카드 스냅샷
   *
   * @throws CustomException 공유 불가는 TALK_ROUTINE_NOT_SHAREABLE, 권한·없는 일과는 일과 접근 오류
   */
  @Transactional(readOnly = true)
  public RoutineShareSnapshot snapshotForShare(Caller caller, String routineId) {
    Routine requested = RoutineRules.routineFor(
      routineRepository, profileAccessGuard, caller, routineId, RoutineAction.VIEW);
    Routine original = resolveOriginal(caller, requested);
    if (!isShareable(original)) {
      log.info("[talk share] rejected : routine is not shareable");
      throw new CustomException(ErrorCode.TALK_ROUTINE_NOT_SHAREABLE);
    }
    return new RoutineShareSnapshot(
      original.getId(),
      original.getTitle(),
      original.getLanguage(),
      original.getProfile().getNickname(),
      original.getSteps().stream().map(RoutineShareService::toStepSnapshot).toList());
  }

  /**
   * 일과의 이룸이 호칭 (글 고치기 때 한마디 이름 가리기용): 일과가 지워졌으면 null, 권한 확인 없음(글쓴이 확인은 호출부)
   */
  @Transactional(readOnly = true)
  public String findProfileNickname(String routineId) {
    if (routineId == null) {
      return null;
    }
    return routineRepository.findById(routineId)
      .map(routine -> routine.getProfile().getNickname())
      .orElse(null);
  }

  /**
   * 일과 그림 읽기 (없거나 읽기 실패는 null, 던지지 않음)
   */
  public ImageContent readImage(String imageKey) {
    if (imageKey == null) {
      return null;
    }
    try {
      return routineImageStorage.read(imageKey);
    } catch (RuntimeException e) {
      log.warn("[talk share] image read failed : card image skipped");
      return null;
    }
  }

  // 오늘 일과 복사본 > 원본 (원본을 못 찾으면 공유 불가, 원본에도 같은 권한 확인)
  private Routine resolveOriginal(Caller caller, Routine requested) {
    String sourceRoutineId = requested.getSourceRoutineId();
    if (sourceRoutineId == null) {
      return requested;
    }
    Routine original = routineRepository.findById(sourceRoutineId)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_ROUTINE_NOT_SHAREABLE));
    profileAccessGuard.checkRoutine(
      caller, original.getProfile().getId(), original.getCreatedBy(), RoutineAction.VIEW);
    return original;
  }

  // 공유 불가 4개: 예시, 일과관리에서 지움, 이야기에서 가져온 일과(재공유 금지), 승인 전
  private static boolean isShareable(Routine original) {
    boolean isExample = Boolean.TRUE.equals(original.getIsExample());
    boolean isImportedFromTalk = original.getTalkPostId() != null;
    boolean isPendingReview = original.getStatus() == RoutineStatus.PENDING_REVIEW;
    return !isExample && !original.isLibraryHidden() && !isImportedFromTalk && !isPendingReview;
  }

  private static StepSnapshot toStepSnapshot(RoutineStep step) {
    return new StepSnapshot(
      step.getId(),
      step.getStepOrder(),
      step.getTitle(),
      step.getDescription(),
      step.getImagePath(),
      step.getPictogramId(),
      step.getExampleImageId(),
      RoutineImageStorage.isGuardianUploadedPhoto(step.getImagePath()));
  }
}
