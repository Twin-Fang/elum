package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkSharePage;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkPostVisibility;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 인증 없는 공유 링크: 내려간 글·정지 회원 글이 앱 밖 웹에 드러나지 않게, 썸네일은 그림 있는 첫 카드만.
@ExtendWith(MockitoExtension.class)
class TalkSharePageServiceTest {

  private static final String POST_ID = "0b6f6b1e-3c1a-4f7e-9d7a-2a4c5e6f7a8b";
  private static final String AUTHOR_ID = "author-1";
  private static final String SOURCE_ROUTINE_ID = "routine-1";

  @Mock
  private RoutineShareService routineShareService;
  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkBlockRepository talkBlockRepository;
  @Mock
  private TalkPostStepRepository talkPostStepRepository;
  @Mock
  private TalkImageStorage talkImageStorage;
  @Mock
  private MemberService memberService;

  private TalkSharePageService service;

  @BeforeEach
  void setUp() {
    TalkPostAccess talkPostAccess =
      new TalkPostAccess(talkPostRepository, talkBlockRepository, memberService, routineShareService);
    service = new TalkSharePageService(talkPostAccess, talkPostStepRepository, talkImageStorage);
  }

  @Test
  @DisplayName("보이는 글은 분류·제목·한마디·카드 수를 싣는다")
  void page_visiblePost_returnsPreview() {
    when(talkPostRepository.findById(POST_ID)).thenReturn(Optional.of(post(TalkPostStatus.VISIBLE, "아침에 같이 해요")));
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of());

    Optional<TalkSharePage> page = service.page(POST_ID);

    assertThat(page).isPresent();
    assertThat(page.get().title()).isEqualTo("아침 준비");
    assertThat(page.get().categoryLabel()).isEqualTo(TalkCategory.DAILY_FLOW.getLabel());
    assertThat(page.get().notePreview()).isEqualTo("아침에 같이 해요");
    assertThat(page.get().stepCount()).isEqualTo(3);
  }

  @Test
  @DisplayName("내려간 글은 빈 결과 — 웹에 드러나지 않는다")
  void page_hiddenPost_returnsEmpty() {
    when(talkPostRepository.findById(POST_ID)).thenReturn(Optional.of(post(TalkPostStatus.HIDDEN_BY_ADMIN, null)));

    assertThat(service.page(POST_ID)).isEmpty();
  }

  @Test
  @DisplayName("정지 회원 글은 빈 결과")
  void page_suspendedAuthor_returnsEmpty() {
    when(talkPostRepository.findById(POST_ID)).thenReturn(Optional.of(post(TalkPostStatus.VISIBLE, null)));
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of(AUTHOR_ID));

    assertThat(service.page(POST_ID)).isEmpty();
  }

  @Test
  @DisplayName("보낸 사람이 끈 링크(내린 글)는 빈 결과 — 끈 링크로 일과를 계속 볼 수 없다")
  void page_turnedOffLink_returnsEmpty() {
    when(talkPostRepository.findById(POST_ID)).thenReturn(Optional.of(linkPost(TalkPostStatus.DELETED)));

    assertThat(service.page(POST_ID)).isEmpty();
    assertThat(service.thumbnail(POST_ID)).isEmpty();
  }

  @Test
  @DisplayName("원본 일과를 지웠거나 보낸 사람 연결이 끊긴 링크는 빈 결과, 살아 있으면 분류 없이 링크 글로 싣는다")
  void page_linkWithUnavailableSource_returnsEmpty() {
    when(talkPostRepository.findById(POST_ID)).thenReturn(Optional.of(linkPost(TalkPostStatus.VISIBLE)));
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of());
    when(routineShareService.isLinkSourceAvailable(SOURCE_ROUTINE_ID, AUTHOR_ID)).thenReturn(false, true);

    assertThat(service.page(POST_ID)).isEmpty();
    Optional<TalkSharePage> alive = service.page(POST_ID);
    assertThat(alive).isPresent();
    assertThat(alive.get().linkOnly()).isTrue();
    assertThat(alive.get().categoryLabel()).isNull();
  }

  @Test
  @DisplayName("UUID 모양이 아닌 id 는 DB 를 보지 않고 빈 결과")
  void page_malformedId_skipsLookup() {
    assertThat(service.page("../../etc/passwd")).isEmpty();
    verify(talkPostRepository, never()).findById("../../etc/passwd");
  }

  @Test
  @DisplayName("썸네일은 그림이 있는 첫 카드 (픽토그램 카드는 건너뜀)")
  void thumbnail_firstImageStep() {
    when(talkPostRepository.findById(POST_ID)).thenReturn(Optional.of(post(TalkPostStatus.VISIBLE, null)));
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of());
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc(POST_ID)).thenReturn(List.of(
      step(1, null), step(2, POST_ID + "/2.jpg"), step(3, POST_ID + "/3.jpg")));
    ImageContent image = new ImageContent(new byte[] {1}, "image/jpeg");
    when(talkImageStorage.read(POST_ID + "/2.jpg")).thenReturn(image);

    assertThat(service.thumbnail(POST_ID)).contains(image);
  }

  @Test
  @DisplayName("그림 읽기 실패면 빈 결과 (기본 그림으로 대신)")
  void thumbnail_readFailure_returnsEmpty() {
    when(talkPostRepository.findById(POST_ID)).thenReturn(Optional.of(post(TalkPostStatus.VISIBLE, null)));
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of());
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc(POST_ID)).thenReturn(List.of(step(1, POST_ID + "/1.jpg")));
    when(talkImageStorage.read(POST_ID + "/1.jpg")).thenThrow(new CustomException(ErrorCode.TALK_IMAGE_NOT_FOUND));

    assertThat(service.thumbnail(POST_ID)).isEmpty();
  }

  // 링크 글: 분류·한마디 없음, 원본 일과 있음
  private static TalkPost linkPost(TalkPostStatus status) {
    TalkPost post = post(status, null);
    post.setCategory(null);
    post.setVisibility(TalkPostVisibility.LINK_ONLY);
    post.setSourceRoutineId(SOURCE_ROUTINE_ID);
    return post;
  }

  private static TalkPost post(TalkPostStatus status, String note) {
    TalkPost post = new TalkPost();
    post.setId(POST_ID);
    post.setAuthorMemberId(AUTHOR_ID);
    post.setTitle("아침 준비");
    post.setNote(note);
    post.setCategory(TalkCategory.DAILY_FLOW);
    post.setStatus(status);
    post.setStepCount(3);
    return post;
  }

  private static TalkPostStep step(int stepOrder, String imageKey) {
    TalkPostStep step = new TalkPostStep();
    step.setPostId(POST_ID);
    step.setStepOrder(stepOrder);
    step.setImageKey(imageKey);
    return step;
  }
}
