package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.core.RoutinePhotoProcessor;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.io.IOException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

/**
 * 보호자가 카드 그림을 직접 찍은 사진으로 바꾼다 (이슈 #455).
 *
 * <p><b>AI 를 부르지 않고 크레딧도 쓰지 않는다.</b> 그래서 크레딧 서비스를 주입받지 않는다 — 쓸 수 없게
 * 두는 것이 "타지 않는다"를 가장 확실하게 지킨다.
 *
 * <p>순서: 권한·카드 확인 → 검증·재인코딩 → 새 파일 저장 → DB 경로 갱신 → (롤백이면 새 파일 삭제 /
 * 커밋이면 옛 파일 삭제). 파일을 먼저 쓰고 DB 를 나중에 고치므로, 어느 단계가 실패해도 카드는 옛 그림을
 * 그대로 가리킨다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineStepPhotoService {

  private final RoutineRepository routineRepository;
  private final RoutineStepRepository routineStepRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutinePhotoProcessor routinePhotoProcessor;
  private final RoutineImageStorage routineImageStorage;

  @Transactional
  public RoutineStepResponse replaceStepImage(Caller caller, String routineId, String stepId, MultipartFile image) {
    // 카드 수정과 같은 권한이다 — 이룸이는 EDIT 불가, 일과를 만든 보호자만 가능.
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    profileAccessGuard.checkRoutine(caller, routine.getProfile().getId(), routine.getCreatedBy(), RoutineAction.EDIT);
    RoutineStep step = routine.getSteps().stream()
      .filter(candidate -> candidate.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    byte[] processed = routinePhotoProcessor.process(readBytes(image));

    String newKey = routineImageStorage.saveUploaded(stepId, processed);
    deleteOnRollback(newKey);

    String oldKey = step.getImagePath();
    step.setImagePath(newKey);
    deleteOldAfterCommit(oldKey, stepId);

    return RoutineStepResponse.from(step);
  }

  /** 크기는 바이트를 읽기 <b>전에</b> 본다 — 큰 파일을 메모리에 올린 뒤에야 거절하지 않게. */
  private byte[] readBytes(MultipartFile image) {
    if (image == null || image.isEmpty()) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
    }
    if (image.getSize() > RoutinePhotoProcessor.MAX_BYTES) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE);
    }
    try {
      return image.getBytes();
    } catch (IOException e) {
      log.warn("카드 사진 업로드를 읽지 못했다", e);
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
    }
  }

  /** 트랜잭션이 되돌려지면 방금 쓴 파일을 지운다 — 아무도 가리키지 않는 파일이 쌓이지 않게. */
  private void deleteOnRollback(String newKey) {
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCompletion(int status) {
        if (status == STATUS_ROLLED_BACK) {
          routineImageStorage.delete(newKey);
        }
      }
    });
  }

  /**
   * 옛 그림은 <b>커밋된 뒤에</b> 지운다. 먼저 지웠는데 롤백되면 DB 는 옛 열쇠를 가리키는데 파일이 없다.
   * 트랜잭션 밖(단위 테스트)에서는 바로 지운다.
   */
  private void deleteOldAfterCommit(String oldKey, String stepId) {
    if (oldKey == null || oldKey.isBlank()) {
      return;
    }
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
        @Override
        public void afterCommit() {
          deleteOldIfUnreferenced(oldKey, stepId);
        }
      });
      return;
    }
    deleteOldIfUnreferenced(oldKey, stepId);
  }

  /**
   * 일과 복제는 그림 파일을 새로 만들지 않고 같은 열쇠를 공유한다. 다른 카드가 아직 가리키면 지우지
   * 않는다. 지우다 실패해도 요청은 이미 성공했다 — 경고만 남긴다.
   */
  private void deleteOldIfUnreferenced(String oldKey, String stepId) {
    try {
      if (routineStepRepository.existsByImagePathAndIdNot(oldKey, stepId)) {
        return;
      }
      routineImageStorage.delete(oldKey);
    } catch (RuntimeException e) {
      log.warn("카드의 옛 그림을 지우지 못했다: stepId={}, key={}", stepId, oldKey, e);
    }
  }
}
