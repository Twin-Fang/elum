package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.core.RoutinePhotoProcessor;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

/**
 * 카드 그림을 사진으로 바꾸기 (이슈 #455).
 *
 * <p>사진 가공은 {@link RoutinePhotoProcessor} 를 가짜로 두고 "무엇을 불렀는가"만 본다.
 * 가공 자체는 자기 테스트가 있다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepPhotoServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final byte[] RAW = {1, 2, 3};
  private static final byte[] PROCESSED = {9, 9};

  @Mock private RoutineRepository routineRepository;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RoutinePhotoProcessor routinePhotoProcessor;
  @Mock private RoutineImageStorage routineImageStorage;
  /// 서비스가 받지 않는 협력자다. 부르지 않았음을 보이려고 만들어 둔다.
  @Mock private CreditReservationService creditReservationService;

  private RoutineStepPhotoService service() {
    return new RoutineStepPhotoService(routineRepository, routineStepRepository, profileAccessGuard,
      routinePhotoProcessor, routineImageStorage);
  }

  @AfterEach
  void clearSynchronization() {
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      TransactionSynchronizationManager.clearSynchronization();
    }
  }

  private MultipartFile file() {
    return new MockMultipartFile("image", "photo.jpg", "image/jpeg", RAW);
  }

  private void givenHappyPath(Routine routine) {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    when(routinePhotoProcessor.process(RAW)).thenReturn(PROCESSED);
    when(routineImageStorage.saveUploaded("step-1", PROCESSED)).thenReturn("step-1/new.jpg");
  }

  // ── 정상 ────────────────────────────────────────────

  @Test
  @DisplayName("정상 교체 — imagePath 가 새 열쇠로 바뀌고 응답에 담긴다")
  void replace_updatesImagePath() {
    Routine routine = routine("step-1/old.png");
    givenHappyPath(routine);

    RoutineStepResponse response = service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file());

    assertThat(response.imagePath()).isEqualTo("step-1/new.jpg");
    assertThat(routine.getSteps().get(0).getImagePath()).isEqualTo("step-1/new.jpg");
    verify(profileAccessGuard).checkRoutine(GUARDIAN, "profile-1", "member-1", RoutineAction.EDIT);
  }

  @Test
  @DisplayName("AI 도 크레딧도 건드리지 않는다")
  void replace_neverTouchesCredit() {
    givenHappyPath(routine(null));

    service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file());

    verifyNoInteractions(creditReservationService);
  }

  @Test
  @DisplayName("그림이 없던 카드(AI 실패)에도 사진을 올릴 수 있고, 지울 옛 파일은 없다")
  void replace_fromNull() {
    givenHappyPath(routine(null));

    service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file());

    verify(routineImageStorage, never()).delete(anyString());
  }

  // ── 권한 · 대상 ──────────────────────────────────────

  @Test
  @DisplayName("권한이 없으면(이룸이·비작성자·다른 이룸이) 아무것도 읽거나 쓰지 않고 거절한다")
  void replace_forbidden() {
    Routine routine = routine("step-1/old.png");
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    for (ErrorCode code : List.of(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI, ErrorCode.ROUTINE_NOT_CREATOR,
      ErrorCode.ROUTINE_ACCESS_DENIED)) {
      doThrow(new CustomException(code)).when(profileAccessGuard)
        .checkRoutine(any(), anyString(), anyString(), any());

      assertThatThrownBy(() -> service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file()))
        .isInstanceOf(CustomException.class)
        .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(code));
    }

    verifyNoInteractions(routinePhotoProcessor, routineImageStorage);
    assertThat(routine.getSteps().get(0).getImagePath()).isEqualTo("step-1/old.png");
  }

  @Test
  @DisplayName("없는 일과·없는 카드는 404")
  void replace_notFound() {
    when(routineRepository.findById("nope")).thenReturn(Optional.empty());
    assertCode(() -> service().replaceStepImage(GUARDIAN, "nope", "step-1", file()), ErrorCode.ROUTINE_NOT_FOUND);

    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine("x")));
    assertCode(() -> service().replaceStepImage(GUARDIAN, "routine-1", "step-99", file()),
      ErrorCode.ROUTINE_STEP_NOT_FOUND);

    verifyNoInteractions(routinePhotoProcessor, routineImageStorage);
  }

  // ── 크기 · 형식 ──────────────────────────────────────

  @Test
  @DisplayName("5MB 를 넘으면 바이트를 읽기 전에 거절한다")
  void replace_tooLarge_beforeReading() {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine("x")));
    MultipartFile big = org.mockito.Mockito.mock(MultipartFile.class);
    when(big.isEmpty()).thenReturn(false);
    when(big.getSize()).thenReturn(RoutinePhotoProcessor.MAX_BYTES + 1L);

    assertCode(() -> service().replaceStepImage(GUARDIAN, "routine-1", "step-1", big),
      ErrorCode.ROUTINE_STEP_IMAGE_TOO_LARGE);

    try {
      verify(big, never()).getBytes();
    } catch (java.io.IOException e) {
      throw new IllegalStateException(e);
    }
    verifyNoInteractions(routinePhotoProcessor, routineImageStorage);
  }

  @Test
  @DisplayName("정확히 5MB 는 받는다")
  void replace_exactLimit_accepted() {
    Routine routine = routine(null);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    byte[] exact = new byte[RoutinePhotoProcessor.MAX_BYTES];
    when(routinePhotoProcessor.process(exact)).thenReturn(PROCESSED);
    when(routineImageStorage.saveUploaded("step-1", PROCESSED)).thenReturn("step-1/new.jpg");

    service().replaceStepImage(GUARDIAN, "routine-1", "step-1", new MockMultipartFile("image", exact));

    assertThat(routine.getSteps().get(0).getImagePath()).isEqualTo("step-1/new.jpg");
  }

  @Test
  @DisplayName("파일이 비었거나 없으면 형식 오류")
  void replace_emptyFile() {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine("x")));

    assertCode(() -> service().replaceStepImage(GUARDIAN, "routine-1", "step-1",
      new MockMultipartFile("image", new byte[0])), ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
    assertCode(() -> service().replaceStepImage(GUARDIAN, "routine-1", "step-1", null),
      ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);
  }

  @Test
  @DisplayName("가공이 거절하면(형식 오류) 저장하지 않고 imagePath 도 그대로다")
  void replace_processorRejects() {
    Routine routine = routine("step-1/old.png");
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    when(routinePhotoProcessor.process(RAW))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE));

    assertCode(() -> service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file()),
      ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE);

    verifyNoInteractions(routineImageStorage);
    assertThat(routine.getSteps().get(0).getImagePath()).isEqualTo("step-1/old.png");
  }

  // ── 저장 실패 · 롤백 ─────────────────────────────────

  @Test
  @DisplayName("저장이 실패하면 imagePath 는 옛 값 그대로이고 옛 파일도 지우지 않는다")
  void replace_saveFails_keepsOld() {
    Routine routine = routine("step-1/old.png");
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    when(routinePhotoProcessor.process(RAW)).thenReturn(PROCESSED);
    when(routineImageStorage.saveUploaded("step-1", PROCESSED))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED));

    assertCode(() -> service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file()),
      ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);

    assertThat(routine.getSteps().get(0).getImagePath()).isEqualTo("step-1/old.png");
    verify(routineImageStorage, never()).delete(anyString());
  }

  @Test
  @DisplayName("트랜잭션이 롤백되면 방금 쓴 새 파일을 지우고 옛 파일은 지우지 않는다")
  void replace_rollback_deletesNewFile() {
    givenHappyPath(routine("step-1/old.png"));
    TransactionSynchronizationManager.initSynchronization();

    service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file());
    finish(TransactionSynchronization.STATUS_ROLLED_BACK);

    verify(routineImageStorage).delete("step-1/new.jpg");
    verify(routineImageStorage, never()).delete("step-1/old.png");
  }

  @Test
  @DisplayName("커밋되기 전에는 옛 파일을 지우지 않고, 커밋 뒤에 지운다")
  void replace_commit_deletesOldAfterCommit() {
    givenHappyPath(routine("step-1/old.png"));
    when(routineStepRepository.existsByImagePathAndIdNot("step-1/old.png", "step-1")).thenReturn(false);
    TransactionSynchronizationManager.initSynchronization();

    service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file());
    verify(routineImageStorage, never()).delete(anyString());

    List<TransactionSynchronization> callbacks = TransactionSynchronizationManager.getSynchronizations();
    callbacks.forEach(TransactionSynchronization::afterCommit);
    callbacks.forEach(sync -> sync.afterCompletion(TransactionSynchronization.STATUS_COMMITTED));

    verify(routineImageStorage).delete("step-1/old.png");
    verify(routineImageStorage, never()).delete("step-1/new.jpg");
  }

  // ── 옛 파일 공유 ─────────────────────────────────────

  @Test
  @DisplayName("다른 카드(복제본)가 옛 그림을 가리키면 지우지 않는다")
  void replace_sharedOldFile_kept() {
    givenHappyPath(routine("shared/1.png"));
    when(routineStepRepository.existsByImagePathAndIdNot("shared/1.png", "step-1")).thenReturn(true);

    service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file());

    verify(routineImageStorage, never()).delete(anyString());
  }

  @Test
  @DisplayName("아무도 가리키지 않는 옛 그림은 지운다")
  void replace_unsharedOldFile_deleted() {
    givenHappyPath(routine("step-1/old.png"));
    when(routineStepRepository.existsByImagePathAndIdNot("step-1/old.png", "step-1")).thenReturn(false);

    service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file());

    verify(routineImageStorage).delete("step-1/old.png");
  }

  @Test
  @DisplayName("옛 파일 삭제가 실패해도 요청은 성공한다")
  void replace_oldDeleteFails_stillSucceeds() {
    givenHappyPath(routine("step-1/old.png"));
    when(routineStepRepository.existsByImagePathAndIdNot(anyString(), anyString())).thenReturn(false);
    doThrow(new IllegalStateException("디스크 오류")).when(routineImageStorage).delete("step-1/old.png");

    RoutineStepResponse response = service().replaceStepImage(GUARDIAN, "routine-1", "step-1", file());

    assertThat(response.imagePath()).isEqualTo("step-1/new.jpg");
  }

  // ── 도움 ────────────────────────────────────────────

  private void finish(int status) {
    List<TransactionSynchronization> callbacks = TransactionSynchronizationManager.getSynchronizations();
    callbacks.forEach(sync -> sync.afterCompletion(status));
  }

  private void assertCode(Runnable call, ErrorCode expected) {
    assertThatThrownBy(call::run)
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(expected));
  }

  private Routine routine(String imagePath) {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");

    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setProfile(profile);
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setCreatedBy("member-1");

    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setStepOrder(1);
    step.setTitle("제목");
    step.setDescription("설명");
    step.setImagePath(imagePath);
    List<RoutineStep> steps = new ArrayList<>();
    steps.add(step);
    routine.setSteps(steps);
    return routine;
  }
}
