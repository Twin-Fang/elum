package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft.DraftStep;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineGroup;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineGroupRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
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
  @Mock
  private RoutineGroupRepository routineGroupRepository;
  @Mock
  private RoutineGroupMembership routineGroupMembership;
  @Mock
  private RoutineLibraryOrderService routineLibraryOrderService;
  @Mock
  private RoutineStepSpeechQueue routineStepSpeechQueue;

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
  @DisplayName("링크로 보내기: 같은 이룸이의 다른 보호자가 만든 일과는 TALK_LINK_ROUTINE_NOT_MINE (볼 수는 있어도 보낼 수 없다)")
  void snapshotForLinkShare_otherGuardiansRoutine_rejected() {
    Routine othersRoutine = routine("original-1", "버스 타기");
    othersRoutine.setCreatedBy("member-2");
    when(routineRepository.findById("original-1")).thenReturn(Optional.of(othersRoutine));

    assertThatThrownBy(() -> routineShareService.snapshotForLinkShare(GUARDIAN, "original-1"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_LINK_ROUTINE_NOT_MINE));
  }

  @Test
  @DisplayName("링크 원본: 일과관리에서 지웠거나 보낸 사람이 이룸이 연결에서 빠지면 꺼진 것으로 본다")
  void isLinkSourceAvailable_hiddenOrDisconnected_false() {
    Routine hidden = routine("hidden-1", "지운 일과");
    hidden.setLibraryHidden(true);
    when(routineRepository.findById("hidden-1")).thenReturn(Optional.of(hidden));
    when(routineRepository.findById("original-1")).thenReturn(Optional.of(routine("original-1", "버스 타기")));
    when(profileAccessGuard.isGuardianOf("member-1", "profile-1")).thenReturn(false, true);

    assertThat(routineShareService.isLinkSourceAvailable("hidden-1", "member-1")).isFalse();
    assertThat(routineShareService.isLinkSourceAvailable("original-1", "member-1")).isFalse();
    assertThat(routineShareService.isLinkSourceAvailable("original-1", "member-1")).isTrue();
  }

  @Test
  @DisplayName("링크로 받은 일과는 받은 보호자가 만든 사람이 되고, 그 일과는 다시 링크로 보낼 수 없다")
  void importToLibrary_fromLink_ownedByReceiverAndNotResendable() {
    Caller receiver = Caller.guardian("receiver-1");
    stubProfileAccess();
    stubSaveAssigningStepIds();

    routineShareService.importToLibrary(receiver, "profile-1", null, draft(step(0, null)));

    Routine saved = savedRoutine();
    assertThat(saved.getCreatedBy()).isEqualTo("receiver-1");
    when(routineRepository.findById("saved-routine")).thenReturn(Optional.of(saved));
    assertThatThrownBy(() -> routineShareService.snapshotForLinkShare(receiver, "saved-routine"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_LINK_ROUTINE_NOT_SHAREABLE));
  }

  @Test
  @DisplayName("일과의 이룸이 호칭을 돌려주고, 지워진 일과·null id 는 null")
  void findProfileNickname_returnsNicknameOrNull() {
    when(routineRepository.findById("original-1")).thenReturn(Optional.of(routine("original-1", "버스 타기")));
    when(routineRepository.findById("gone-1")).thenReturn(Optional.empty());

    assertThat(routineShareService.findProfileNickname("original-1")).isEqualTo("하늘이");
    assertThat(routineShareService.findProfileNickname("gone-1")).isNull();
    assertThat(routineShareService.findProfileNickname(null)).isNull();
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

  @Test
  @DisplayName("가져오면 일과관리에만 있는 보낸 상태 원본이 만들어지고 글 id 가 남는다")
  void importToLibrary_createsLibraryOnlyConfirmedOriginal() {
    stubProfileAccess();
    stubSaveAssigningStepIds();

    String routineId = routineShareService.importToLibrary(GUARDIAN, "profile-1", null, draft(step(0, null)));

    Routine saved = savedRoutine();
    assertThat(routineId).isEqualTo(saved.getId());
    assertThat(saved.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(saved.isLibraryOnly()).isTrue();
    assertThat(saved.getSourceRoutineId()).isNull();
    assertThat(saved.getTalkPostId()).isEqualTo("post-1");
    assertThat(saved.getCreatedBy()).isEqualTo("member-1");
    assertThat(saved.getProfile().getId()).isEqualTo("profile-1");
    assertThat(saved.getTitle()).isEqualTo("가져온 일과");
    assertThat(saved.getRawInputText()).isEqualTo("가져온 일과");
    assertThat(saved.getLanguage()).isEqualTo(AppLocale.EN);
    assertThat(saved.getScheduledAt()).isNotNull();
    verify(routineStepSpeechQueue).enqueueAfterCommit(anyCollection());
  }

  @Test
  @DisplayName("묶음 없이 가져오면 일과관리 맨 앞에 놓고 기존 칸은 한 칸씩 밀린다")
  void importToLibrary_noGroup_placedFirst() {
    stubProfileAccess();
    stubSaveAssigningStepIds();

    routineShareService.importToLibrary(GUARDIAN, "profile-1", null, draft(step(0, null)));

    verify(routineLibraryOrderService).makeRoomAtFront("profile-1");
    Routine saved = savedRoutine();
    assertThat(saved.getLibraryOrder()).isZero();
    assertThat(saved.getGroupId()).isNull();
    verify(routineGroupMembership, never()).assign(anyString(), any());
  }

  @Test
  @DisplayName("묶음을 고르면 그 묶음의 맨 뒤에 들어간다")
  void importToLibrary_withGroup_placedLast() {
    stubProfileAccess();
    stubSaveAssigningStepIds();
    RoutineGroup group = groupOf("group-1", "profile-1");
    Routine first = routine("existing-1", "먼저");
    Routine second = routine("existing-2", "그다음");
    when(routineGroupRepository.findById("group-1")).thenReturn(Optional.of(group));
    when(routineGroupMembership.membersOf("group-1")).thenReturn(List.of(first, second));

    routineShareService.importToLibrary(GUARDIAN, "profile-1", "group-1", draft(step(0, null)));

    @SuppressWarnings("unchecked")
    ArgumentCaptor<List<Routine>> orderedRoutines = ArgumentCaptor.forClass(List.class);
    verify(routineGroupMembership).assign(eq("group-1"), orderedRoutines.capture());
    assertThat(orderedRoutines.getValue()).extracting(Routine::getTitle).containsExactly("먼저", "그다음", "가져온 일과");
    verify(routineLibraryOrderService, never()).makeRoomAtFront(anyString());
  }

  @Test
  @DisplayName("다른 이룸이의 묶음이거나 없는 묶음이면 INVALID_INPUT_VALUE, 아무것도 저장하지 않는다")
  void importToLibrary_foreignGroup_throwsInvalidInput() {
    stubProfileAccess();
    when(routineGroupRepository.findById("group-foreign")).thenReturn(Optional.of(groupOf("group-foreign", "profile-2")));
    when(routineGroupRepository.findById("group-gone")).thenReturn(Optional.empty());

    assertImportRejected("group-foreign", ErrorCode.INVALID_INPUT_VALUE);
    assertImportRejected("group-gone", ErrorCode.INVALID_INPUT_VALUE);
    verify(routineRepository, never()).save(any());
  }

  @Test
  @DisplayName("연결되지 않은 이룸이로는 가져올 수 없다")
  void importToLibrary_otherProfile_throwsAccessDenied() {
    when(profileAccessGuard.profileFor(any(Caller.class), eq(ProfileAction.MANAGE)))
      .thenThrow(new CustomException(ErrorCode.PROFILE_ACCESS_DENIED));

    assertImportRejected(null, ErrorCode.PROFILE_ACCESS_DENIED);
    verify(routineRepository, never()).save(any());
  }

  @Test
  @DisplayName("그림 없는 카드는 픽토그램·예시 이미지를 그대로 갖고, 그림 저장을 부르지 않는다")
  void importToLibrary_stepWithoutImage_keepsPictogram() {
    stubProfileAccess();
    stubSaveAssigningStepIds();

    routineShareService.importToLibrary(GUARDIAN, "profile-1", null, draft(step(0, null)));

    RoutineStep savedStep = savedRoutine().getSteps().get(0);
    assertThat(savedStep.getPictogramId()).isEqualTo("pictogram-0");
    assertThat(savedStep.getExampleImageId()).isEqualTo("example-0");
    assertThat(savedStep.getTitle()).isEqualTo("카드 0");
    assertThat(savedStep.getDescription()).isEqualTo("설명 0");
    assertThat(savedStep.getStepOrder()).isZero();
    assertThat(savedStep.getCompleted()).isFalse();
    assertThat(savedStep.getImagePath()).isNull();
    verify(routineImageStorage, never()).saveImported(anyString(), any());
  }

  @Test
  @DisplayName("그림이 있는 카드는 가져온 그림 열쇠를 갖는다")
  void importToLibrary_stepWithImage_savesImportedKey() {
    stubProfileAccess();
    stubSaveAssigningStepIds();
    ImageContent image = new ImageContent(new byte[]{1}, "image/png");
    when(routineImageStorage.saveImported("saved-step-0", image)).thenReturn("saved-step-0/talk-1.png");

    routineShareService.importToLibrary(GUARDIAN, "profile-1", null, draft(step(0, image)));

    assertThat(savedRoutine().getSteps().get(0).getImagePath()).isEqualTo("saved-step-0/talk-1.png");
  }

  @Test
  @DisplayName("한 카드의 그림 저장이 실패해도 그 카드만 그림 없이 두고 계속한다")
  void importToLibrary_imageSaveFails_continuesWithoutImage() {
    stubProfileAccess();
    stubSaveAssigningStepIds();
    ImageContent broken = new ImageContent(new byte[]{1}, "image/png");
    ImageContent healthy = new ImageContent(new byte[]{2}, "image/jpeg");
    when(routineImageStorage.saveImported("saved-step-0", broken))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED));
    when(routineImageStorage.saveImported("saved-step-1", healthy)).thenReturn("saved-step-1/talk-2.jpg");

    String routineId = routineShareService.importToLibrary(GUARDIAN, "profile-1", null,
      draft(step(0, broken), step(1, healthy)));

    List<RoutineStep> steps = savedRoutine().getSteps();
    assertThat(routineId).isNotNull();
    assertThat(steps.get(0).getImagePath()).isNull();
    assertThat(steps.get(0).getPictogramId()).isEqualTo("pictogram-0");
    assertThat(steps.get(1).getImagePath()).isEqualTo("saved-step-1/talk-2.jpg");
  }

  private void assertImportRejected(String groupId, ErrorCode expected) {
    assertThatThrownBy(() -> routineShareService.importToLibrary(GUARDIAN, "profile-1", groupId, draft(step(0, null))))
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(expected));
  }

  private void stubProfileAccess() {
    when(profileAccessGuard.profileFor(any(Caller.class), eq(ProfileAction.MANAGE))).thenReturn(profileOf("profile-1"));
  }

  // 저장 흉내: 일과·카드에 id 를 붙여 돌려줌
  private void stubSaveAssigningStepIds() {
    when(routineRepository.save(any(Routine.class))).thenAnswer(invocation -> {
      Routine routine = invocation.getArgument(0);
      routine.setId("saved-routine");
      for (RoutineStep step : routine.getSteps()) {
        step.setId("saved-step-" + step.getStepOrder());
      }
      return routine;
    });
  }

  private Routine savedRoutine() {
    ArgumentCaptor<Routine> captor = ArgumentCaptor.forClass(Routine.class);
    verify(routineRepository).save(captor.capture());
    return captor.getValue();
  }

  private static RoutineImportDraft draft(DraftStep... steps) {
    return new RoutineImportDraft("post-1", "가져온 일과", AppLocale.EN, List.of(steps));
  }

  private static DraftStep step(int order, ImageContent image) {
    return new DraftStep(order, "카드 " + order, "설명 " + order, "pictogram-" + order, "example-" + order, image);
  }

  private static RoutineGroup groupOf(String id, String profileId) {
    RoutineGroup group = new RoutineGroup();
    group.setId(id);
    group.setProfile(profileOf(profileId));
    return group;
  }

  private static Profile profileOf(String id) {
    Profile profile = new Profile();
    profile.setId(id);
    return profile;
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
