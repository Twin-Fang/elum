package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.notification.core.event.TalkPostImportedEvent;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.request.TalkImportRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkImportResponse;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkImport;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

/// 가져가기: 내린 글을 가져가거나, 같은 보호자의 반복 가져가기가 횟수를 부풀리는 것을 막는다.
@ExtendWith(MockitoExtension.class)
class TalkImportServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkPostStepRepository talkPostStepRepository;
  @Mock
  private TalkImportRepository talkImportRepository;
  @Mock
  private TalkBlockRepository talkBlockRepository;
  @Mock
  private TalkImageStorage talkImageStorage;
  @Mock
  private RoutineShareService routineShareService;
  @Mock
  private ApplicationEventPublisher eventPublisher;

  private TalkImportService talkImportService;

  @BeforeEach
  void setUp() {
    talkImportService = new TalkImportService(
      talkPostRepository, talkPostStepRepository, talkImportRepository, talkBlockRepository, talkImageStorage,
      routineShareService, eventPublisher);
  }

  @Test
  @DisplayName("내렸거나 없는 글은 TALK_POST_NOT_FOUND, 일과를 만들지 않는다")
  void importToLibrary_deletedPost_throwsNotFound() {
    TalkPost deleted = post(TalkPostStatus.DELETED);
    when(talkPostRepository.findById("post-deleted")).thenReturn(Optional.of(deleted));
    when(talkPostRepository.findById("post-gone")).thenReturn(Optional.empty());

    assertImportRejected("post-deleted", ErrorCode.TALK_POST_NOT_FOUND);
    assertImportRejected("post-gone", ErrorCode.TALK_POST_NOT_FOUND);
    verifyNoInteractions(routineShareService);
    verify(talkImportRepository, never()).save(any());
  }

  @Test
  @DisplayName("글 카드와 그림으로 초안을 만들어 일과 쪽에 맡기고 가져간 기록을 남긴다")
  void importToLibrary_buildsDraftAndRecordsImport() {
    TalkPost post = post(TalkPostStatus.VISIBLE);
    ImageContent image = new ImageContent(new byte[]{1}, "image/jpeg");
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc("post-1"))
      .thenReturn(List.of(step(0, "post-1/0.jpg"), step(1, null)));
    when(talkImageStorage.read("post-1/0.jpg")).thenReturn(image);
    when(routineShareService.importToLibrary(eq(GUARDIAN), eq("profile-1"), eq("group-1"), any()))
      .thenReturn("routine-1");

    TalkImportResponse response = talkImportService.importToLibrary(
      GUARDIAN, "post-1", new TalkImportRequest("profile-1", "group-1"));

    assertThat(response.routineId()).isEqualTo("routine-1");
    assertThat(response.profileId()).isEqualTo("profile-1");
    ArgumentCaptor<RoutineImportDraft> draft = ArgumentCaptor.forClass(RoutineImportDraft.class);
    verify(routineShareService).importToLibrary(eq(GUARDIAN), eq("profile-1"), eq("group-1"), draft.capture());
    assertThat(draft.getValue().talkPostId()).isEqualTo("post-1");
    assertThat(draft.getValue().title()).isEqualTo("버스 타기");
    assertThat(draft.getValue().language()).isEqualTo(AppLocale.KO);
    assertThat(draft.getValue().steps()).hasSize(2);
    assertThat(draft.getValue().steps().get(0).image()).isSameAs(image);
    assertThat(draft.getValue().steps().get(0).pictogramId()).isEqualTo("pictogram-0");
    assertThat(draft.getValue().steps().get(1).image()).isNull();
    ArgumentCaptor<TalkImport> record = ArgumentCaptor.forClass(TalkImport.class);
    verify(talkImportRepository).save(record.capture());
    assertThat(record.getValue().getPostId()).isEqualTo("post-1");
    assertThat(record.getValue().getMemberId()).isEqualTo("member-1");
    assertThat(record.getValue().getProfileId()).isEqualTo("profile-1");
    assertThat(record.getValue().getRoutineId()).isEqualTo("routine-1");
  }

  @Test
  @DisplayName("그림을 읽지 못한 카드는 그림 없이 가져가고 계속한다")
  void importToLibrary_imageReadFails_continuesWithoutImage() {
    TalkPost post = post(TalkPostStatus.VISIBLE);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc("post-1")).thenReturn(List.of(step(0, "post-1/0.jpg")));
    when(talkImageStorage.read("post-1/0.jpg")).thenThrow(new CustomException(ErrorCode.TALK_IMAGE_NOT_FOUND));
    when(routineShareService.importToLibrary(any(), any(), any(), any())).thenReturn("routine-1");

    talkImportService.importToLibrary(GUARDIAN, "post-1", new TalkImportRequest("profile-1", null));

    ArgumentCaptor<RoutineImportDraft> draft = ArgumentCaptor.forClass(RoutineImportDraft.class);
    verify(routineShareService).importToLibrary(any(), any(), any(), draft.capture());
    assertThat(draft.getValue().steps().get(0).image()).isNull();
  }

  @Test
  @DisplayName("같은 보호자가 두 번 가져가도 가져간 수는 한 번만 오른다")
  void importToLibrary_countsEachGuardianOnce() {
    TalkPost post = post(TalkPostStatus.VISIBLE);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc("post-1")).thenReturn(List.of(step(0, null)));
    when(routineShareService.importToLibrary(any(), any(), any(), any())).thenReturn("routine-1", "routine-2");
    when(talkImportRepository.existsByPostIdAndMemberId("post-1", "member-1")).thenReturn(false, true);

    talkImportService.importToLibrary(GUARDIAN, "post-1", new TalkImportRequest("profile-1", null));
    talkImportService.importToLibrary(GUARDIAN, "post-1", new TalkImportRequest("profile-1", null));

    assertThat(post.getImportCount()).isEqualTo(1);
    // 기록은 가져갈 때마다 남음 (일과 연결 추적용)
    verify(talkImportRepository, org.mockito.Mockito.times(2)).save(any(TalkImport.class));
  }

  @Test
  @DisplayName("보호자의 첫 가져가기에만 글쓴이·행동한 사람·글 제목을 담은 알림 이벤트를 내보낸다")
  void importToLibrary_publishesEvent_onlyOnFirstImport() {
    TalkPost post = post(TalkPostStatus.VISIBLE);
    post.setAuthorMemberId("author-1");
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc("post-1")).thenReturn(List.of(step(0, null)));
    when(routineShareService.importToLibrary(any(), any(), any(), any())).thenReturn("routine-1", "routine-2");
    when(talkImportRepository.existsByPostIdAndMemberId("post-1", "member-1")).thenReturn(false, true);

    talkImportService.importToLibrary(GUARDIAN, "post-1", new TalkImportRequest("profile-1", null));
    talkImportService.importToLibrary(GUARDIAN, "post-1", new TalkImportRequest("profile-1", null));

    verify(eventPublisher, org.mockito.Mockito.times(1))
      .publishEvent(new TalkPostImportedEvent("post-1", "author-1", "member-1", "버스 타기"));
  }

  @Test
  @DisplayName("글쓴이가 가져간 보호자를 차단했으면 알림 이벤트를 내보내지 않고 가져가기는 그대로 된다")
  void importToLibrary_authorBlockedActor_publishesNoEvent() {
    TalkPost post = post(TalkPostStatus.VISIBLE);
    post.setAuthorMemberId("author-1");
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc("post-1")).thenReturn(List.of(step(0, null)));
    when(routineShareService.importToLibrary(any(), any(), any(), any())).thenReturn("routine-1");
    when(talkImportRepository.existsByPostIdAndMemberId("post-1", "member-1")).thenReturn(false);
    when(talkBlockRepository.existsByBlockerMemberIdAndBlockedMemberId("author-1", "member-1")).thenReturn(true);

    talkImportService.importToLibrary(GUARDIAN, "post-1", new TalkImportRequest("profile-1", null));

    assertThat(post.getImportCount()).isEqualTo(1);
    verify(eventPublisher, never()).publishEvent(any(Object.class));
  }

  @Test
  @DisplayName("이룸이를 안 골랐으면 INVALID_INPUT_VALUE")
  void importToLibrary_blankProfile_throwsInvalidInput() {
    assertThatThrownBy(() -> talkImportService.importToLibrary(GUARDIAN, "post-1", new TalkImportRequest(" ", null)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    assertThatThrownBy(() -> talkImportService.importToLibrary(GUARDIAN, "post-1", null))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    verifyNoInteractions(routineShareService);
  }

  private void assertImportRejected(String postId, ErrorCode expected) {
    assertThatThrownBy(() -> talkImportService.importToLibrary(
      GUARDIAN, postId, new TalkImportRequest("profile-1", null)))
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(expected));
  }

  private static TalkPost post(TalkPostStatus status) {
    TalkPost post = new TalkPost();
    post.setId("post-1");
    post.setTitle("버스 타기");
    post.setLanguage(AppLocale.KO);
    post.setStatus(status);
    return post;
  }

  private static TalkPostStep step(int order, String imageKey) {
    TalkPostStep step = new TalkPostStep();
    step.setPostId("post-1");
    step.setStepOrder(order);
    step.setTitle("카드 " + order);
    step.setDescription("설명 " + order);
    step.setImageKey(imageKey);
    step.setPictogramId("pictogram-" + order);
    step.setExampleImageId("example-" + order);
    return step;
  }
}
