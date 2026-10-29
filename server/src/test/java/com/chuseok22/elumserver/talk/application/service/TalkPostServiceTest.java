package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.member.core.NicknamePolicy;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot.StepSnapshot;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPostCreateRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPostUpdateRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPreviewRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostCreatedResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostDetailResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPreviewResponse;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.image.TalkImageBlurrer;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.util.List;
import java.util.Optional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.dao.DataIntegrityViolationException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.MockedStatic;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 올리기·고치기·내리기: 이룸이 실명 노출·원본 사진 노출·남의 글 수정·내린 글의 그림 잔재를 막는다.
@ExtendWith(MockitoExtension.class)
class TalkPostServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final String PHOTO_KEY_1 = "step-1/3f2a9c0d-1b2e-4f60-8a7b-123456789abc.jpg";
  private static final String PHOTO_KEY_2 = "step-2/4f2a9c0d-1b2e-4f60-8a7b-123456789abc.jpg";

  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkPostStepRepository talkPostStepRepository;
  @Mock
  private TalkImageStorage talkImageStorage;
  @Mock
  private TalkImageBlurrer talkImageBlurrer;
  @Mock
  private RoutineShareService routineShareService;
  @Mock
  private MemberService memberService;
  @Mock
  private TalkFeedQueryService talkFeedQueryService;

  private TalkPostService talkPostService;

  @BeforeEach
  void setUp() {
    talkPostService = new TalkPostService(talkPostRepository, talkPostStepRepository, talkImageStorage,
      talkImageBlurrer, routineShareService, memberService, new NicknamePolicy(), talkFeedQueryService);
  }

  @Test
  @DisplayName("제목·카드 설명·한마디의 이룸이 호칭이 '이룸이'로 바뀌어 저장된다")
  void create_masksNicknameInTitleStepsAndNote() {
    stubCreatable(snapshot("하늘이", "하늘이 버스 타기",
      step("step-1", 1, "버스를 타요", "하늘이가 카드를 찍어요", null, false)));

    talkPostService.create(GUARDIAN, request("하늘이는 좋아했어요", "DAILY_FLOW", List.of()));

    TalkPost post = savedPost();
    assertThat(post.getTitle()).doesNotContain("하늘이").contains("이룸이");
    assertThat(post.getNote()).doesNotContain("하늘이").contains("이룸이");
    assertThat(savedSteps().get(0).getDescription()).doesNotContain("하늘이").contains("이룸이");
    assertThat(post.getAuthorMemberId()).isEqualTo("member-1");
    assertThat(post.getSourceRoutineId()).isEqualTo("original-1");
    assertThat(post.getCategory()).isEqualTo(TalkCategory.DAILY_FLOW);
    assertThat(post.getStepCount()).isEqualTo(1);
  }

  @Test
  @DisplayName("호칭이 없으면 글을 그대로 두고 올린다")
  void create_withoutNickname_keepsTextAndSucceeds() {
    stubCreatable(snapshot(null, "버스 타기", step("step-1", 1, "버스를 타요", "하늘이가 찍어요", null, false)));

    TalkPostCreatedResponse response = talkPostService.create(GUARDIAN, request("메모", "DAILY_FLOW", List.of()));

    assertThat(response.postId()).isEqualTo("post-1");
    assertThat(savedPost().getTitle()).isEqualTo("버스 타기");
    assertThat(savedSteps().get(0).getDescription()).isEqualTo("하늘이가 찍어요");
  }

  @Test
  @DisplayName("가리기 중 예외가 나면 원문을 쓰지 않고 TALK_NICKNAME_MASK_FAILED 로 거절한다")
  void create_maskThrows_rejectsWithMaskFailed() {
    stubAgreedAndSnapshot(snapshot("하늘이", "버스 타기", step("s1", 1, "버스를 타요", "하늘이가 찍어요", null, false)));
    when(talkPostRepository.existsBySourceRoutineIdAndStatus("original-1", TalkPostStatus.VISIBLE)).thenReturn(false);

    try (MockedStatic<NicknamePlaceholder> placeholder = mockStatic(NicknamePlaceholder.class)) {
      placeholder.when(() -> NicknamePlaceholder.mask(any(), any(), any())).thenThrow(new IllegalStateException("boom"));

      assertCreateFails(request(null, "DAILY_FLOW", List.of()), ErrorCode.TALK_NICKNAME_MASK_FAILED);
    }
    verify(talkPostRepository, never()).saveAndFlush(any());
  }

  @Test
  @DisplayName("호칭이 낱말 일부로 남아도(하늘색) 실제 가리기 경로에서 호칭이 사라지고, 조사 붙은 호칭은 이룸이로 바뀐다")
  void create_realMask_replacesNicknameInsideWordsAndKeepsParticles() {
    stubCreatable(snapshot("하늘", "하늘색 옷 입기",
      step("s1", 1, "옷", "하늘색 옷을 입어요", null, false),
      step("s2", 2, "찍기", "하늘이가 카드를 찍어요", null, false)));

    talkPostService.create(GUARDIAN, request("하늘 이야기", "SELF_CARE", List.of()));

    assertThat(savedPost().getTitle()).doesNotContain("하늘");
    assertThat(savedPost().getNote()).doesNotContain("하늘");
    assertThat(savedSteps().get(0).getDescription()).doesNotContain("하늘").contains("이룸이");
    assertThat(savedSteps().get(1).getDescription()).doesNotContain("하늘").contains("이룸이가");
  }

  @Test
  @DisplayName("호칭이 자리표시와 같으면(이룸이) 가리기·검증을 건너뛰고 올린다")
  void create_nicknameSameAsPlaceholder_succeeds() {
    stubCreatable(snapshot("이룸이", "이룸이 버스 타기", step("s1", 1, "버스", "이룸이가 버스를 타요", null, false)));

    talkPostService.create(GUARDIAN, request(null, "DAILY_FLOW", List.of()));

    assertThat(savedPost().getTitle()).isEqualTo("이룸이 버스 타기");
  }

  @Test
  @DisplayName("가린 뒤에도 호칭이 남으면 TALK_NICKNAME_MASK_FAILED (치환이 새 호칭 모양을 만든 경우)")
  void create_nicknameRemainsAfterMask_rejects() {
    // "이하" 를 "이룸이" 로 바꾸면 뒤 글자와 이어져 다시 "이하" 가 생긴다
    stubAgreedAndSnapshot(snapshot("이하", "이하하 버스 타기", step("s1", 1, "버스", "버스를 타요", null, false)));
    when(talkPostRepository.existsBySourceRoutineIdAndStatus("original-1", TalkPostStatus.VISIBLE)).thenReturn(false);

    assertCreateFails(request(null, "DAILY_FLOW", List.of()), ErrorCode.TALK_NICKNAME_MASK_FAILED);
    verify(talkPostRepository, never()).saveAndFlush(any());
  }

  @Test
  @DisplayName("동시에 같은 원본을 올려 유니크 인덱스에 걸리면 TALK_ALREADY_SHARED 로 바꾸고 카드는 저장하지 않는다")
  void create_concurrentDuplicate_mapsToAlreadyShared() {
    stubAgreedAndSnapshot(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "정류장에 가요", null, false)));
    when(talkPostRepository.existsBySourceRoutineIdAndStatus("original-1", TalkPostStatus.VISIBLE)).thenReturn(false);
    when(talkPostRepository.saveAndFlush(any(TalkPost.class))).thenThrow(new DataIntegrityViolationException("uk"));

    assertCreateFails(request(null, "DAILY_FLOW", List.of()), ErrorCode.TALK_ALREADY_SHARED);
    verify(talkPostStepRepository, never()).saveAll(any());
  }

  @Test
  @DisplayName("그림 정리가 실패해도 원래 예외(그림 저장 실패)가 그대로 나간다")
  void create_cleanupFails_originalExceptionSurvives() {
    stubCreatable(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "정류장에 가요", "batch/1.png", false)));
    when(routineShareService.readImage("batch/1.png")).thenReturn(new ImageContent(new byte[]{1}, "image/png"));
    when(talkImageStorage.save(anyString(), anyInt(), any(), anyString()))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED));
    doThrow(new IllegalStateException("disk")).when(talkImageStorage).deletePost("post-1");

    assertCreateFails(request(null, "DAILY_FLOW", List.of()), ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED);
  }

  @Test
  @DisplayName("고른 사진만 흐리게, 안 고른 사진·AI 그림은 원본 바이트 그대로 복사한다")
  void create_blurOnlySelectedPhotos() {
    byte[] photo1 = {1, 1};
    byte[] photo2 = {2, 2};
    byte[] aiPicture = {3, 3};
    byte[] blurredPhoto2 = {9, 9};
    stubCreatable(snapshot("하늘이", "버스 타기",
      step("s1", 1, "정류장", "정류장에 가요", PHOTO_KEY_1, true),
      step("s2", 2, "버스", "버스를 타요", PHOTO_KEY_2, true),
      step("aiStep", 3, "내려요", "내려요", "batch/1.png", false)));
    when(routineShareService.readImage(PHOTO_KEY_1)).thenReturn(new ImageContent(photo1, "image/jpeg"));
    when(routineShareService.readImage(PHOTO_KEY_2)).thenReturn(new ImageContent(photo2, "image/jpeg"));
    when(routineShareService.readImage("batch/1.png")).thenReturn(new ImageContent(aiPicture, "image/png"));
    when(talkImageBlurrer.blur(photo2)).thenReturn(blurredPhoto2);
    when(talkImageStorage.save(anyString(), anyInt(), any(), anyString()))
      .thenAnswer(invocation -> invocation.getArgument(0) + "/" + invocation.getArgument(1) + ".jpg");

    talkPostService.create(GUARDIAN, request(null, "DAILY_FLOW", List.of("s2", "aiStep")));

    verify(talkImageBlurrer, times(1)).blur(any());
    verify(talkImageStorage).save("post-1", 0, photo1, "image/jpeg");
    verify(talkImageStorage).save("post-1", 1, blurredPhoto2, "image/jpeg");
    verify(talkImageStorage).save("post-1", 2, aiPicture, "image/png");
    assertThat(savedSteps()).extracting(TalkPostStep::isBlurred).containsExactly(false, true, false);
    assertThat(savedSteps()).extracting(TalkPostStep::getImageKey)
      .containsExactly("post-1/0.jpg", "post-1/1.jpg", "post-1/2.jpg");
  }

  @Test
  @DisplayName("그림이 없는 카드는 픽토그램·예시 이미지 id 만 복사한다")
  void create_stepWithoutImage_copiesPictogramOnly() {
    StepSnapshot pictogramOnly = new StepSnapshot("s1", 1, "씻기", "손을 씻어요", null, "wash_hands", "example-7", false);
    stubCreatable(snapshot("하늘이", "씻기", pictogramOnly));

    talkPostService.create(GUARDIAN, request(null, "SELF_CARE", List.of()));

    TalkPostStep saved = savedSteps().get(0);
    assertThat(saved.getImageKey()).isNull();
    assertThat(saved.getPictogramId()).isEqualTo("wash_hands");
    assertThat(saved.getExampleImageId()).isEqualTo("example-7");
    verifyNoInteractions(talkImageStorage, talkImageBlurrer);
  }

  @Test
  @DisplayName("그림 읽기에 실패한 카드는 imageKey 없이 저장하고 계속한다")
  void create_unreadableImage_savesWithoutImageKey() {
    stubCreatable(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "정류장에 가요", PHOTO_KEY_1, true)));
    when(routineShareService.readImage(PHOTO_KEY_1)).thenReturn(null);

    talkPostService.create(GUARDIAN, request(null, "DAILY_FLOW", List.of("s1")));

    assertThat(savedSteps().get(0).getImageKey()).isNull();
    assertThat(savedSteps().get(0).isBlurred()).isFalse();
    verify(talkImageStorage, never()).save(anyString(), anyInt(), any(), anyString());
  }

  @Test
  @DisplayName("그림 저장 중 예외가 나면 이미 쓴 파일을 글 단위로 지우고 예외를 다시 던진다")
  void create_imageSaveFails_deletesWrittenFilesAndRethrows() {
    stubCreatable(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "정류장에 가요", "batch/1.png", false)));
    when(routineShareService.readImage("batch/1.png")).thenReturn(new ImageContent(new byte[]{1}, "image/png"));
    when(talkImageStorage.save(anyString(), anyInt(), any(), anyString()))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED));

    assertThatThrownBy(() -> talkPostService.create(GUARDIAN, request(null, "DAILY_FLOW", List.of())))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.ROUTINE_STEP_IMAGE_SAVE_FAILED));
    verify(talkImageStorage).deletePost("post-1");
    verify(talkPostStepRepository, never()).saveAll(any());
  }

  @Test
  @DisplayName("흐리게 고른 사진을 흐리지 못하면 원본을 올리지 않고 롤백한다")
  void create_blurFails_neverFallsBackToOriginal() {
    byte[] photo = {1, 1};
    stubCreatable(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "정류장에 가요", PHOTO_KEY_1, true)));
    when(routineShareService.readImage(PHOTO_KEY_1)).thenReturn(new ImageContent(photo, "image/jpeg"));
    when(talkImageBlurrer.blur(photo)).thenThrow(new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_INVALID_TYPE));

    assertThatThrownBy(() -> talkPostService.create(GUARDIAN, request(null, "DAILY_FLOW", List.of("s1"))))
      .isInstanceOf(CustomException.class);
    verify(talkImageStorage, never()).save(anyString(), anyInt(), any(), anyString());
    verify(talkImageStorage).deletePost("post-1");
  }

  @Test
  @DisplayName("이용 규칙에 동의하지 않으면 TALK_RULES_NOT_AGREED")
  void create_notAgreedRules_throws() {
    when(memberService.hasAgreedTalkRules("member-1")).thenReturn(false);

    assertCreateFails(request(null, "DAILY_FLOW", List.of()), ErrorCode.TALK_RULES_NOT_AGREED);
    verifyNoInteractions(routineShareService, talkPostRepository);
  }

  @Test
  @DisplayName("같은 원본의 보이는 글이 이미 있으면 TALK_ALREADY_SHARED")
  void create_alreadyShared_throws() {
    stubAgreedAndSnapshot(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "정류장에 가요", null, false)));
    when(talkPostRepository.existsBySourceRoutineIdAndStatus("original-1", TalkPostStatus.VISIBLE)).thenReturn(true);

    assertCreateFails(request(null, "DAILY_FLOW", List.of()), ErrorCode.TALK_ALREADY_SHARED);
    verify(talkPostRepository, never()).saveAndFlush(any());
  }

  @Test
  @DisplayName("모르는 분류는 INVALID_INPUT_VALUE")
  void create_unknownCategory_throwsInvalidInput() {
    when(memberService.hasAgreedTalkRules("member-1")).thenReturn(true);

    assertCreateFails(request(null, "NOPE", List.of()), ErrorCode.INVALID_INPUT_VALUE);
  }

  @Test
  @DisplayName("한마디가 300자를 넘으면 TALK_TEXT_TOO_LONG")
  void create_noteOver300_throwsTooLong() {
    when(memberService.hasAgreedTalkRules("member-1")).thenReturn(true);

    assertCreateFails(request("가".repeat(301), "DAILY_FLOW", List.of()), ErrorCode.TALK_TEXT_TOO_LONG);
  }

  @Test
  @DisplayName("한마디에 금칙어가 있으면 TALK_TEXT_NOT_ALLOWED")
  void create_blockedWordInNote_throwsNotAllowed() {
    stubAgreedAndSnapshot(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "정류장에 가요", null, false)));
    when(talkPostRepository.existsBySourceRoutineIdAndStatus("original-1", TalkPostStatus.VISIBLE)).thenReturn(false);

    assertCreateFails(request("이거 개새끼 별로예요", "DAILY_FLOW", List.of()), ErrorCode.TALK_TEXT_NOT_ALLOWED);
    verify(talkPostRepository, never()).saveAndFlush(any());
  }

  @Test
  @DisplayName("카드 글에 금칙어가 있으면 TALK_TEXT_NOT_ALLOWED")
  void create_blockedWordInStep_throwsNotAllowed() {
    stubAgreedAndSnapshot(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "개새끼 빨리 가요", null, false)));
    when(talkPostRepository.existsBySourceRoutineIdAndStatus("original-1", TalkPostStatus.VISIBLE)).thenReturn(false);

    assertCreateFails(request(null, "DAILY_FLOW", List.of()), ErrorCode.TALK_TEXT_NOT_ALLOWED);
  }

  @Test
  @DisplayName("미리보기는 사진 카드 여부와 이름 가린 글을 돌려주고 아무것도 저장하지 않는다")
  void preview_reportsGuardianPhotoAndMaskedText() {
    RoutineShareSnapshot snapshot = snapshot("하늘이", "하늘이 버스 타기",
      step("s1", 1, "정류장", "하늘이가 정류장에 가요", PHOTO_KEY_1, true),
      step("s2", 2, "버스", "버스를 타요", "batch/1.png", false));
    when(routineShareService.snapshotForShare(GUARDIAN, "routine-1")).thenReturn(snapshot);

    TalkPreviewResponse response = talkPostService.preview(GUARDIAN, new TalkPreviewRequest("routine-1"));

    assertThat(response.title()).doesNotContain("하늘이").contains("이룸이");
    assertThat(response.hasGuardianPhoto()).isTrue();
    assertThat(response.steps()).extracting(TalkPreviewResponse.PreviewStep::stepId).containsExactly("s1", "s2");
    assertThat(response.steps()).extracting(TalkPreviewResponse.PreviewStep::isGuardianPhoto)
      .containsExactly(true, false);
    assertThat(response.steps().get(0).description()).doesNotContain("하늘이").contains("이룸이");
    verifyNoInteractions(talkPostRepository, talkPostStepRepository, talkImageStorage, talkImageBlurrer);
  }

  @Test
  @DisplayName("작성자가 아니면 고칠 수 없다 (TALK_NOT_AUTHOR) 그리고 아무것도 바꾸지 않는다")
  void update_byOther_throwsNotAuthor() {
    TalkPost post = visiblePost("post-1", "other-member", "원래 한마디", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));

    assertUpdateFails("post-1", new TalkPostUpdateRequest("바꿈", null), ErrorCode.TALK_NOT_AUTHOR);
    assertThat(post.getNote()).isEqualTo("원래 한마디");
    verify(talkPostRepository, never()).save(any());
  }

  @Test
  @DisplayName("없거나 이미 내린 글은 TALK_POST_NOT_FOUND")
  void update_missingOrDeleted_throwsNotFound() {
    TalkPost deleted = visiblePost("post-2", "member-1", null, TalkCategory.DAILY_FLOW);
    deleted.setStatus(TalkPostStatus.DELETED);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.empty());
    when(talkPostRepository.findById("post-2")).thenReturn(Optional.of(deleted));

    assertUpdateFails("post-1", new TalkPostUpdateRequest("바꿈", null), ErrorCode.TALK_POST_NOT_FOUND);
    assertUpdateFails("post-2", new TalkPostUpdateRequest("바꿈", null), ErrorCode.TALK_POST_NOT_FOUND);
  }

  @Test
  @DisplayName("한마디·분류를 둘 다 안 보내면 INVALID_INPUT_VALUE")
  void update_nothingToChange_throwsInvalidInput() {
    assertUpdateFails("post-1", new TalkPostUpdateRequest(null, null), ErrorCode.INVALID_INPUT_VALUE);
    assertUpdateFails("post-1", null, ErrorCode.INVALID_INPUT_VALUE);
    verifyNoInteractions(talkPostRepository);
  }

  @Test
  @DisplayName("고친 한마디도 이룸이 호칭을 가리고 저장하고, 상세를 돌려준다")
  void update_noteMaskedAndChecked() {
    TalkPost post = visiblePost("post-1", "member-1", "원래", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(routineShareService.findProfileNickname("original-1")).thenReturn("하늘이");
    TalkPostDetailResponse detail = mock(TalkPostDetailResponse.class);
    when(talkFeedQueryService.detail(GUARDIAN, "post-1")).thenReturn(detail);

    TalkPostDetailResponse response =
      talkPostService.update(GUARDIAN, "post-1", new TalkPostUpdateRequest("  하늘이는 좋아했어요 ", null));

    assertThat(post.getNote()).doesNotContain("하늘이").contains("이룸이");
    assertThat(post.getCategory()).isEqualTo(TalkCategory.DAILY_FLOW);
    assertThat(response).isSameAs(detail);
    verify(talkPostRepository).saveAndFlush(post);
  }

  @Test
  @DisplayName("고친 한마디에 금칙어가 있으면 TALK_TEXT_NOT_ALLOWED 로 거절하고 글은 그대로다")
  void update_blockedWord_rejectsAndKeepsPost() {
    TalkPost post = visiblePost("post-1", "member-1", "원래", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(routineShareService.findProfileNickname("original-1")).thenReturn("하늘이");

    assertUpdateFails("post-1", new TalkPostUpdateRequest("이거 개새끼 별로예요", null), ErrorCode.TALK_TEXT_NOT_ALLOWED);
    assertThat(post.getNote()).isEqualTo("원래");
    verify(talkPostRepository, never()).saveAndFlush(any());
  }

  @Test
  @DisplayName("가린 뒤에도 호칭이 남거나 가리기 중 예외가 나면 TALK_NICKNAME_MASK_FAILED")
  void update_maskFails_rejects() {
    TalkPost post = visiblePost("post-1", "member-1", "원래", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    // "이하" 를 "이룸이" 로 바꾸면 뒤 글자와 이어져 다시 "이하" 가 생긴다
    when(routineShareService.findProfileNickname("original-1")).thenReturn("이하");

    assertUpdateFails("post-1", new TalkPostUpdateRequest("이하하 좋아요", null), ErrorCode.TALK_NICKNAME_MASK_FAILED);
    assertThat(post.getNote()).isEqualTo("원래");
  }

  @Test
  @DisplayName("분류만 보내면 한마디는 그대로 두고 분류만 바꾼다 (원본 일과는 조회하지 않음)")
  void update_categoryOnly_keepsNote() {
    TalkPost post = visiblePost("post-1", "member-1", "원래 한마디", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));

    talkPostService.update(GUARDIAN, "post-1", new TalkPostUpdateRequest(null, "FEELINGS"));

    assertThat(post.getCategory()).isEqualTo(TalkCategory.FEELINGS);
    assertThat(post.getNote()).isEqualTo("원래 한마디");
    verifyNoInteractions(routineShareService);
  }

  @Test
  @DisplayName("모르는 분류는 INVALID_INPUT_VALUE, 빈 한마디는 한마디를 지운다")
  void update_unknownCategoryRejected_emptyNoteClears() {
    TalkPost post = visiblePost("post-1", "member-1", "원래 한마디", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));

    assertUpdateFails("post-1", new TalkPostUpdateRequest(null, "NOPE"), ErrorCode.INVALID_INPUT_VALUE);

    talkPostService.update(GUARDIAN, "post-1", new TalkPostUpdateRequest("   ", null));
    assertThat(post.getNote()).isNull();
  }

  @Test
  @DisplayName("원본 일과가 지워졌으면 호칭 없이(글 그대로) 고친다")
  void update_sourceRoutineGone_keepsTextUnchanged() {
    TalkPost post = visiblePost("post-1", "member-1", "원래", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(routineShareService.findProfileNickname("original-1")).thenReturn(null);

    talkPostService.update(GUARDIAN, "post-1", new TalkPostUpdateRequest("하늘이는 좋아했어요", null));

    assertThat(post.getNote()).isEqualTo("하늘이는 좋아했어요");
  }

  @Test
  @DisplayName("내리면 제목·한마디를 비우고 DELETED 로 바꾸며 카드를 지우고, 그림 파일은 커밋 뒤에만 지운다")
  void delete_marksDeleted_andSchedulesImageRemoval() {
    TalkPost post = visiblePost("post-1", "member-1", "한마디", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    TransactionSynchronizationManager.initSynchronization();
    try {
      talkPostService.delete(GUARDIAN, "post-1");

      assertThat(post.getStatus()).isEqualTo(TalkPostStatus.DELETED);
      assertThat(post.getTitle()).isEmpty();
      assertThat(post.getNote()).isNull();
      verify(talkPostRepository).saveAndFlush(post);
      verify(talkPostStepRepository).deleteAllByPostId("post-1");
      verify(talkImageStorage, never()).deletePost(anyString());

      TransactionSynchronizationManager.getSynchronizations().forEach(TransactionSynchronization::afterCommit);
      verify(talkImageStorage).deletePost("post-1");
    } finally {
      TransactionSynchronizationManager.clearSynchronization();
    }
  }

  @Test
  @DisplayName("트랜잭션 밖이면 바로 그림을 지우고, 그림 삭제 실패는 내리기를 막지 않는다")
  void delete_withoutTransaction_removesImagesAndSwallowsFailure() {
    TalkPost post = visiblePost("post-1", "member-1", "한마디", TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    doThrow(new IllegalStateException("disk")).when(talkImageStorage).deletePost("post-1");

    talkPostService.delete(GUARDIAN, "post-1");

    assertThat(post.getStatus()).isEqualTo(TalkPostStatus.DELETED);
  }

  @Test
  @DisplayName("작성자가 아니면 내릴 수 없고, 이미 내린 글은 TALK_POST_NOT_FOUND")
  void delete_byOtherOrAlreadyDeleted_throws() {
    TalkPost others = visiblePost("post-1", "other-member", null, TalkCategory.DAILY_FLOW);
    TalkPost deleted = visiblePost("post-2", "member-1", null, TalkCategory.DAILY_FLOW);
    deleted.setStatus(TalkPostStatus.DELETED);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(others));
    when(talkPostRepository.findById("post-2")).thenReturn(Optional.of(deleted));

    assertThatThrownBy(() -> talkPostService.delete(GUARDIAN, "post-1"))
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_NOT_AUTHOR));
    assertThatThrownBy(() -> talkPostService.delete(GUARDIAN, "post-2"))
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
    assertThat(others.getStatus()).isEqualTo(TalkPostStatus.VISIBLE);
    verify(talkImageStorage, never()).deletePost(anyString());
  }

  @Test
  @DisplayName("내린 뒤 같은 원본을 다시 올릴 수 있다 (중복 확인은 보이는 글만 본다)")
  void delete_thenShareAgain_allowed() {
    TalkPost post = visiblePost("post-1", "member-1", null, TalkCategory.DAILY_FLOW);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    talkPostService.delete(GUARDIAN, "post-1");
    // 저장소 흉내: 같은 원본의 VISIBLE 글은 이제 없다
    when(talkPostRepository.existsBySourceRoutineIdAndStatus("original-1", TalkPostStatus.VISIBLE))
      .thenReturn(post.getStatus() == TalkPostStatus.VISIBLE);
    stubCreatable(snapshot("하늘이", "버스 타기", step("s1", 1, "정류장", "정류장에 가요", null, false)));

    TalkPostCreatedResponse response = talkPostService.create(GUARDIAN, request(null, "DAILY_FLOW", List.of()));

    assertThat(response.postId()).isEqualTo("post-1");
  }

  private void assertUpdateFails(String postId, TalkPostUpdateRequest request, ErrorCode expected) {
    assertThatThrownBy(() -> talkPostService.update(GUARDIAN, postId, request))
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(expected));
  }

  private static TalkPost visiblePost(String id, String authorMemberId, String note, TalkCategory category) {
    TalkPost post = new TalkPost();
    post.setId(id);
    post.setAuthorMemberId(authorMemberId);
    post.setSourceRoutineId("original-1");
    post.setTitle("버스 타기");
    post.setNote(note);
    post.setCategory(category);
    post.setLanguage(AppLocale.KO);
    post.setStatus(TalkPostStatus.VISIBLE);
    return post;
  }

  private void assertCreateFails(TalkPostCreateRequest request, ErrorCode expected) {
    assertThatThrownBy(() -> talkPostService.create(GUARDIAN, request))
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(expected));
  }

  // 동의함 + 스냅샷 + 중복 없음 + 저장 시 id 부여
  private void stubCreatable(RoutineShareSnapshot snapshot) {
    stubAgreedAndSnapshot(snapshot);
    when(talkPostRepository.existsBySourceRoutineIdAndStatus("original-1", TalkPostStatus.VISIBLE)).thenReturn(false);
    when(talkPostRepository.saveAndFlush(any(TalkPost.class))).thenAnswer(invocation -> {
      TalkPost post = invocation.getArgument(0);
      post.setId("post-1");
      return post;
    });
  }

  private void stubAgreedAndSnapshot(RoutineShareSnapshot snapshot) {
    when(memberService.hasAgreedTalkRules("member-1")).thenReturn(true);
    when(routineShareService.snapshotForShare(GUARDIAN, "routine-1")).thenReturn(snapshot);
  }

  private TalkPost savedPost() {
    ArgumentCaptor<TalkPost> captor = ArgumentCaptor.forClass(TalkPost.class);
    verify(talkPostRepository).saveAndFlush(captor.capture());
    return captor.getValue();
  }

  @SuppressWarnings("unchecked")
  private List<TalkPostStep> savedSteps() {
    ArgumentCaptor<List<TalkPostStep>> captor = ArgumentCaptor.forClass(List.class);
    verify(talkPostStepRepository).saveAll(captor.capture());
    return captor.getValue();
  }

  private static TalkPostCreateRequest request(String note, String category, List<String> blurredStepIds) {
    return new TalkPostCreateRequest("routine-1", note, category, blurredStepIds);
  }

  private static RoutineShareSnapshot snapshot(String profileNickname, String title, StepSnapshot... steps) {
    return new RoutineShareSnapshot("original-1", title, AppLocale.KO, profileNickname, List.of(steps));
  }

  private static StepSnapshot step(String stepId, int stepOrder, String title, String description, String imageKey,
    boolean isGuardianPhoto) {
    return new StepSnapshot(stepId, stepOrder, title, description, imageKey, null, null, isGuardianPhoto);
  }
}
