package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 공유 대상 일과를 잘못 고르면 예시·가져온 일과가 새 글이 되거나, 남의 이룸이 일과가 올라간다.
@ExtendWith(MockitoExtension.class)
class RoutineShareServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final String PHOTO_KEY = "step-1/3f2a9c0d-1b2e-4f60-8a7b-123456789abc.jpg";

  @Mock
  private RoutineRepository routineRepository;
  @Mock
  private ProfileAccessGuard profileAccessGuard;
  @Mock
  private RoutineImageStorage routineImageStorage;

  @InjectMocks
  private RoutineShareService routineShareService;

  @Test
  @DisplayName("오늘 일과 복사본은 sourceRoutineId 의 원본 기준으로 뜬다")
  void snapshot_todayCopy_resolvesToOriginal() {
    Routine original = routine("original-1", "버스 타기");
    original.getSteps().add(step(original, "step-1", 1, "정류장에 가요", PHOTO_KEY));
    original.getSteps().add(step(original, "step-2", 2, "버스를 타요", "batch/1.png"));
    Routine todayCopy = routine("copy-1", "버스 타기");
    todayCopy.setSourceRoutineId("original-1");
    when(routineRepository.findById("copy-1")).thenReturn(Optional.of(todayCopy));
    when(routineRepository.findById("original-1")).thenReturn(Optional.of(original));

    RoutineShareSnapshot snapshot = routineShareService.snapshotForShare(GUARDIAN, "copy-1");

    assertThat(snapshot.originalRoutineId()).isEqualTo("original-1");
    assertThat(snapshot.title()).isEqualTo("버스 타기");
    assertThat(snapshot.language()).isEqualTo(AppLocale.KO);
    assertThat(snapshot.profileNickname()).isEqualTo("하늘이");
    assertThat(snapshot.steps()).extracting(RoutineShareSnapshot.StepSnapshot::stepId)
      .containsExactly("step-1", "step-2");
    // 보호자 사진만 true (AI 그림은 false)
    assertThat(snapshot.steps()).extracting(RoutineShareSnapshot.StepSnapshot::isGuardianPhoto)
      .containsExactly(true, false);
    assertThat(snapshot.hasGuardianPhoto()).isTrue();
  }

  @Test
  @DisplayName("예시·일과관리에서 지운 원본은 올릴 수 없다")
  void snapshot_example_rejected() {
    Routine example = routine("example-1", "예시");
    example.setIsExample(true);
    Routine hidden = routine("hidden-1", "지운 일과");
    hidden.setLibraryHidden(true);
    when(routineRepository.findById("example-1")).thenReturn(Optional.of(example));
    when(routineRepository.findById("hidden-1")).thenReturn(Optional.of(hidden));

    assertNotShareable("example-1");
    assertNotShareable("hidden-1");
  }

  @Test
  @DisplayName("이야기에서 가져온 일과는 다시 올릴 수 없다 (오늘 일과 복사본으로 올려도 원본 기준)")
  void snapshot_importedFromTalk_rejected() {
    Routine imported = routine("imported-1", "가져온 일과");
    imported.setTalkPostId("post-1");
    Routine todayCopy = routine("copy-1", "가져온 일과");
    todayCopy.setSourceRoutineId("imported-1");
    when(routineRepository.findById("imported-1")).thenReturn(Optional.of(imported));
    when(routineRepository.findById("copy-1")).thenReturn(Optional.of(todayCopy));

    assertNotShareable("imported-1");
    assertNotShareable("copy-1");
  }

  @Test
  @DisplayName("승인 전 일과·원본을 못 찾는 복사본은 올릴 수 없다")
  void snapshot_pendingReview_rejected() {
    Routine pending = routine("pending-1", "만드는 중");
    pending.setStatus(RoutineStatus.PENDING_REVIEW);
    Routine orphanCopy = routine("copy-1", "원본 없음");
    orphanCopy.setSourceRoutineId("gone-1");
    when(routineRepository.findById("pending-1")).thenReturn(Optional.of(pending));
    when(routineRepository.findById("copy-1")).thenReturn(Optional.of(orphanCopy));
    when(routineRepository.findById("gone-1")).thenReturn(Optional.empty());

    assertNotShareable("pending-1");
    assertNotShareable("copy-1");
  }

  @Test
  @DisplayName("연결되지 않은 이룸이의 일과는 권한 거절")
  void snapshot_otherProfile_accessDenied() {
    Routine other = routine("other-1", "남의 일과");
    when(routineRepository.findById("other-1")).thenReturn(Optional.of(other));
    doThrow(new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED))
      .when(profileAccessGuard).checkRoutine(any(), any(), any(), any());

    assertThatThrownBy(() -> routineShareService.snapshotForShare(GUARDIAN, "other-1"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.ROUTINE_ACCESS_DENIED));
  }

  @Test
  @DisplayName("그림 읽기는 없으면 null, 던지지 않는다")
  void readImage_missingReturnsNull() {
    when(routineImageStorage.read("gone.jpg")).thenThrow(new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND));
    RoutineImageStorage.ImageContent content = new RoutineImageStorage.ImageContent(new byte[]{1}, "image/jpeg");
    when(routineImageStorage.read("there.jpg")).thenReturn(content);

    assertThat(routineShareService.readImage("gone.jpg")).isNull();
    assertThat(routineShareService.readImage("there.jpg")).isSameAs(content);
    assertThat(routineShareService.readImage(null)).isNull();
  }

  private void assertNotShareable(String routineId) {
    assertThatThrownBy(() -> routineShareService.snapshotForShare(GUARDIAN, routineId))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_ROUTINE_NOT_SHAREABLE));
  }

  private static Routine routine(String id, String title) {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("하늘이");
    Routine routine = new Routine();
    routine.setId(id);
    routine.setProfile(profile);
    routine.setCreatedBy("member-1");
    routine.setTitle(title);
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setLanguage(AppLocale.KO);
    routine.setSteps(new ArrayList<>());
    return routine;
  }

  private static RoutineStep step(Routine routine, String id, int order, String description, String imagePath) {
    RoutineStep step = new RoutineStep();
    step.setId(id);
    step.setRoutine(routine);
    step.setStepOrder(order);
    step.setTitle(description);
    step.setDescription(description);
    step.setImagePath(imagePath);
    return step;
  }
}
