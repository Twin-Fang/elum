package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkFeedPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostDetailResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostSummaryResponse;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkCursor;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkHelpfulRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;
import tools.jackson.databind.json.JsonMapper;

/// 피드·인기·상세·그림: 차단·정지 글 노출, 다른 언어 글 노출, 회원 식별자 노출, 내려간 글 그림 노출을 막는다.
@ExtendWith(MockitoExtension.class)
class TalkFeedQueryServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("viewer-1");
  private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 20, 12, 0);

  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkPostStepRepository talkPostStepRepository;
  @Mock
  private TalkBlockRepository talkBlockRepository;
  @Mock
  private TalkHelpfulRepository talkHelpfulRepository;
  @Mock
  private TalkImportRepository talkImportRepository;
  @Mock
  private TalkImageStorage talkImageStorage;
  @Mock
  private MemberService memberService;

  private TalkFeedQueryService service;

  @BeforeEach
  void setUp() {
    Clock clock = Clock.fixed(NOW.atZone(ZONE).toInstant(), ZONE);
    TalkPostAccess talkPostAccess = new TalkPostAccess(talkPostRepository, talkBlockRepository, memberService);
    service = new TalkFeedQueryService(talkPostRepository, talkPostStepRepository, talkHelpfulRepository,
      talkImportRepository, talkImageStorage, memberService, talkPostAccess, clock);
  }

  @Test
  @DisplayName("cursor 형식이 틀리면 첫 쪽(cursor 없음)으로 본다")
  void feed_malformedCursor_returnsFirstPage() {
    when(talkPostRepository.findFeedPage(any(), any(), anyCollection(), any(), anyString(), any()))
      .thenReturn(List.of(post("p1", "author-1", NOW.minusHours(1))));

    TalkFeedPageResponse page = service.feed(GUARDIAN, null, "garbage", null, AppLocale.KO);

    assertThat(page.items()).hasSize(1);
    ArgumentCaptor<LocalDateTime> cursorCreatedAt = ArgumentCaptor.forClass(LocalDateTime.class);
    verify(talkPostRepository).findFeedPage(any(), any(), anyCollection(), cursorCreatedAt.capture(), anyString(), any());
    assertThat(cursorCreatedAt.getValue()).isEqualTo(TalkFeedQueryService.NO_CURSOR_CREATED_AT);
  }

  @Test
  @DisplayName("올바른 cursor 는 그 위치 뒤부터 조회한다")
  void feed_validCursor_queriesAfterPosition() {
    LocalDateTime at = NOW.minusDays(1);

    service.feed(GUARDIAN, null, TalkCursor.encode(at, "p9"), null, AppLocale.KO);

    verify(talkPostRepository).findFeedPage(any(), any(), anyCollection(), eq(at), eq("p9"), any());
  }

  @Test
  @DisplayName("모르는 분류면 INVALID_INPUT_VALUE, 분류가 비면 전체 6개")
  void feed_unknownCategory_throwsInvalidInput() {
    assertThatThrownBy(() -> service.feed(GUARDIAN, "NOPE", null, null, AppLocale.KO))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));

    service.feed(GUARDIAN, " ", null, null, AppLocale.KO);
    ArgumentCaptor<java.util.Collection<TalkCategory>> categories = ArgumentCaptor.forClass(java.util.Collection.class);
    verify(talkPostRepository).findFeedPage(any(), any(), categories.capture(), any(), anyString(), any());
    assertThat(categories.getValue()).containsExactlyInAnyOrder(TalkCategory.values());
  }

  @Test
  @DisplayName("내가 차단한 보호자와 정지된 회원의 글은 빠진다")
  void feed_excludesBlockedAndSuspendedAuthors() {
    TalkBlock block = new TalkBlock();
    block.setBlockerMemberId("viewer-1");
    block.setBlockedMemberId("author-blocked");
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of(block));
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of("author-suspended"));
    when(talkPostRepository.findFeedPage(any(), any(), anyCollection(), any(), anyString(), any()))
      .thenReturn(List.of(
        post("p1", "author-ok", NOW.minusHours(1)),
        post("p2", "author-blocked", NOW.minusHours(2)),
        post("p3", "author-suspended", NOW.minusHours(3))));

    TalkFeedPageResponse page = service.feed(GUARDIAN, null, null, null, AppLocale.KO);

    assertThat(page.items()).extracting(TalkPostSummaryResponse::id).containsExactly("p1");
  }

  @Test
  @DisplayName("보는 사람의 언어로 조회한다")
  void feed_filtersByViewerLanguage() {
    service.feed(GUARDIAN, null, null, null, AppLocale.EN);

    verify(talkPostRepository).findFeedPage(eq(TalkPostStatus.VISIBLE), eq(AppLocale.EN), anyCollection(), any(),
      anyString(), any());
  }

  @Test
  @DisplayName("size 는 1~50 으로 맞추고 한 건 더 읽는다, 기본 20")
  void feed_sizeClampedTo50() {
    service.feed(GUARDIAN, null, null, 999, AppLocale.KO);
    service.feed(GUARDIAN, null, null, null, AppLocale.KO);
    service.feed(GUARDIAN, null, null, 0, AppLocale.KO);

    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
    verify(talkPostRepository, times(3))
      .findFeedPage(any(), any(), anyCollection(), any(), anyString(), pageable.capture());
    assertThat(pageable.getAllValues()).extracting(Pageable::getPageSize).containsExactly(51, 21, 2);
  }

  @Test
  @DisplayName("더 있을 때만 nextCursor 를 준다")
  void feed_returnsNextCursorOnlyWhenMore() {
    List<TalkPost> three = List.of(
      post("p1", "a", NOW.minusHours(1)), post("p2", "a", NOW.minusHours(2)), post("p3", "a", NOW.minusHours(3)));
    when(talkPostRepository.findFeedPage(any(), any(), anyCollection(), any(), anyString(), any())).thenReturn(three);

    TalkFeedPageResponse hasMore = service.feed(GUARDIAN, null, null, 2, AppLocale.KO);

    assertThat(hasMore.items()).extracting(TalkPostSummaryResponse::id).containsExactly("p1", "p2");
    assertThat(hasMore.nextCursor()).isEqualTo(TalkCursor.encode(NOW.minusHours(2), "p2"));

    TalkFeedPageResponse exactlyFull = service.feed(GUARDIAN, null, null, 3, AppLocale.KO);

    assertThat(exactlyFull.items()).hasSize(3);
    assertThat(exactlyFull.nextCursor()).isNull();
  }

  @Test
  @DisplayName("첫 읽기가 모두 차단 글이면 이어 읽고, 이어 읽을 때 cursor 는 직전에 읽은 마지막 글이다")
  void feed_continuesScanWhenWholeBatchIsBlocked() {
    blockAuthor("author-blocked");
    List<TalkPost> blockedBatch = List.of(
      post("b1", "author-blocked", NOW.minusHours(1)), post("b2", "author-blocked", NOW.minusHours(2)),
      post("b3", "author-blocked", NOW.minusHours(3)));
    List<TalkPost> visibleBatch = List.of(
      post("v1", "author-ok", NOW.minusHours(4)), post("v2", "author-ok", NOW.minusHours(5)),
      post("v3", "author-ok", NOW.minusHours(6)));
    when(talkPostRepository.findFeedPage(any(), any(), anyCollection(), any(), anyString(), any()))
      .thenReturn(blockedBatch, visibleBatch);

    TalkFeedPageResponse page = service.feed(GUARDIAN, null, null, 2, AppLocale.KO);

    assertThat(page.items()).extracting(TalkPostSummaryResponse::id).containsExactly("v1", "v2");
    assertThat(page.nextCursor()).isEqualTo(TalkCursor.encode(NOW.minusHours(5), "v2"));
    ArgumentCaptor<LocalDateTime> cursorCreatedAt = ArgumentCaptor.forClass(LocalDateTime.class);
    ArgumentCaptor<String> cursorId = ArgumentCaptor.forClass(String.class);
    verify(talkPostRepository, times(2))
      .findFeedPage(any(), any(), anyCollection(), cursorCreatedAt.capture(), cursorId.capture(), any());
    assertThat(cursorCreatedAt.getAllValues())
      .containsExactly(TalkFeedQueryService.NO_CURSOR_CREATED_AT, NOW.minusHours(3));
    assertThat(cursorId.getAllValues()).containsExactly("", "b3");
  }

  @Test
  @DisplayName("다섯 번 읽어도 전부 차단 글이면 빈 쪽과 마지막으로 읽은 위치의 nextCursor 를 준다")
  void feed_allRoundsBlocked_returnsEmptyPageWithCursorAtLastScanned() {
    blockAuthor("author-blocked");
    List<List<TalkPost>> batches = new ArrayList<>();
    for (int round = 0; round < 5; round++) {
      batches.add(List.of(
        post("r" + round + "a", "author-blocked", NOW.minusHours(round * 10 + 1)),
        post("r" + round + "b", "author-blocked", NOW.minusHours(round * 10 + 2)),
        post("r" + round + "c", "author-blocked", NOW.minusHours(round * 10 + 3))));
    }
    when(talkPostRepository.findFeedPage(any(), any(), anyCollection(), any(), anyString(), any()))
      .thenReturn(batches.get(0), batches.get(1), batches.get(2), batches.get(3), batches.get(4));

    TalkFeedPageResponse page = service.feed(GUARDIAN, null, null, 2, AppLocale.KO);

    assertThat(page.items()).isEmpty();
    assertThat(page.nextCursor()).isEqualTo(TalkCursor.encode(NOW.minusHours(43), "r4c"));
    verify(talkPostRepository, times(5)).findFeedPage(any(), any(), anyCollection(), any(), anyString(), any());
  }

  @Test
  @DisplayName("이어 읽다 짧은 묶음이 오면 끝난 것이라 nextCursor 가 없다")
  void feed_shortBatchAfterBlockedRound_hasNoNextCursor() {
    blockAuthor("author-blocked");
    List<TalkPost> blockedBatch = List.of(
      post("b1", "author-blocked", NOW.minusHours(1)), post("b2", "author-blocked", NOW.minusHours(2)),
      post("b3", "author-blocked", NOW.minusHours(3)));
    when(talkPostRepository.findFeedPage(any(), any(), anyCollection(), any(), anyString(), any()))
      .thenReturn(blockedBatch, List.of(post("v1", "author-ok", NOW.minusHours(4))));

    TalkFeedPageResponse page = service.feed(GUARDIAN, null, null, 2, AppLocale.KO);

    assertThat(page.items()).extracting(TalkPostSummaryResponse::id).containsExactly("v1");
    assertThat(page.nextCursor()).isNull();
    verify(talkPostRepository, times(2)).findFeedPage(any(), any(), anyCollection(), any(), anyString(), any());
  }

  @Test
  @DisplayName("요약은 앞 4장 그림 정보·닉네임·내 글 여부를 담는다")
  void feed_summaryHasPreviewStepsNicknameAndMine() {
    TalkPost mine = post("p1", "viewer-1", NOW.minusHours(1));
    when(talkPostRepository.findFeedPage(any(), any(), anyCollection(), any(), anyString(), any()))
      .thenReturn(List.of(mine, post("p2", "author-2", NOW.minusHours(2))));
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of("viewer-1", "나", "author-2", "다른보호자"));
    when(talkPostStepRepository.findByPostIdInAndStepOrderLessThanOrderByStepOrderAsc(anyCollection(), eq(4)))
      .thenReturn(List.of(step("p1", 0, "img-key", null, null, true), step("p1", 1, null, "7", null, false)));

    List<TalkPostSummaryResponse> items = service.feed(GUARDIAN, null, null, null, AppLocale.KO).items();

    assertThat(items.get(0).isMine()).isTrue();
    assertThat(items.get(0).authorNickname()).isEqualTo("나");
    assertThat(items.get(0).previewSteps()).hasSize(2);
    assertThat(items.get(0).previewSteps().get(0).hasImage()).isTrue();
    assertThat(items.get(0).previewSteps().get(0).isBlurred()).isTrue();
    assertThat(items.get(0).previewSteps().get(1).pictogramId()).isEqualTo("7");
    assertThat(items.get(1).isMine()).isFalse();
    assertThat(items.get(1).previewSteps()).isEmpty();
  }

  @Test
  @DisplayName("인기는 최근 7일 기준으로 조회하고 조회 순서를 지키며 최대 10개다")
  void popular_ordersByDistinctImporters_last7Days_max10() {
    List<String> ids = new ArrayList<>();
    List<TalkPost> posts = new ArrayList<>();
    for (int index = 0; index < 12; index++) {
      ids.add("p" + index);
      posts.add(post("p" + index, "author-1", NOW.minusHours(index)));
    }
    when(talkPostRepository.findPopularPostIds(any(), any(), anyCollection(), any(), any())).thenReturn(ids);
    // 조회 결과는 순서가 뒤섞여 돌아옴 (findAllById 는 순서를 보장하지 않음)
    List<TalkPost> shuffled = new ArrayList<>(posts);
    java.util.Collections.reverse(shuffled);
    when(talkPostRepository.findAllById(anyCollection())).thenReturn(shuffled);

    List<TalkPostSummaryResponse> popular = service.popular(GUARDIAN, null, AppLocale.KO);

    assertThat(popular).hasSize(10);
    assertThat(popular).extracting(TalkPostSummaryResponse::id)
      .containsExactly("p0", "p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "p9");
    verify(talkPostRepository).findPopularPostIds(eq(TalkPostStatus.VISIBLE), eq(AppLocale.KO), anyCollection(),
      eq(NOW.minusDays(7)), any());
  }

  @Test
  @DisplayName("인기에서도 차단·정지 보호자 글은 빠진다")
  void popular_excludesBlockedAndSuspendedAuthors() {
    TalkBlock block = new TalkBlock();
    block.setBlockedMemberId("author-blocked");
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of(block));
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of("author-suspended"));
    when(talkPostRepository.findPopularPostIds(any(), any(), anyCollection(), any(), any()))
      .thenReturn(List.of("p1", "p2", "p3"));
    when(talkPostRepository.findAllById(anyCollection())).thenReturn(List.of(
      post("p1", "author-blocked", NOW), post("p2", "author-suspended", NOW), post("p3", "author-ok", NOW)));

    assertThat(service.popular(GUARDIAN, "DAILY_FLOW", AppLocale.KO))
      .extracting(TalkPostSummaryResponse::id).containsExactly("p3");
  }

  @Test
  @DisplayName("내려간 글(삭제·숨김)의 상세는 TALK_POST_NOT_FOUND")
  void detail_deletedPost_throwsNotFound() {
    TalkPost hidden = post("p1", "author-1", NOW);
    hidden.setStatus(TalkPostStatus.DELETED);
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(hidden));

    assertNotFound("p1");
    assertNotFound("missing");
  }

  @Test
  @DisplayName("내가 차단한 보호자의 글은 상세도 TALK_POST_NOT_FOUND")
  void detail_blockedAuthor_throwsNotFound() {
    TalkBlock block = new TalkBlock();
    block.setBlockedMemberId("author-1");
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of(block));
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", "author-1", NOW)));

    assertNotFound("p1");
  }

  @Test
  @DisplayName("정지된 회원의 글은 상세도 TALK_POST_NOT_FOUND")
  void detail_suspendedAuthor_throwsNotFound() {
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of("author-1"));
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", "author-1", NOW)));

    assertNotFound("p1");
  }

  @Test
  @DisplayName("상세는 내 글 여부, 내가 누른 도움이 됐어요, 내가 가져간 여부를 담는다")
  void detail_marksMineAndHelpful() {
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", "viewer-1", NOW)));
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc("p1"))
      .thenReturn(List.of(step("p1", 0, "img-key", null, null, false), step("p1", 1, null, null, "8", false)));
    when(talkHelpfulRepository.existsByPostIdAndMemberId("p1", "viewer-1")).thenReturn(true);
    when(talkImportRepository.existsByPostIdAndMemberId("p1", "viewer-1")).thenReturn(false);

    TalkPostDetailResponse detail = service.detail(GUARDIAN, "p1");

    assertThat(detail.isMine()).isTrue();
    assertThat(detail.isHelpfulByMe()).isTrue();
    assertThat(detail.isImportedByMe()).isFalse();
    assertThat(detail.steps()).hasSize(2);
    assertThat(detail.steps().get(0).hasImage()).isTrue();
    assertThat(detail.steps().get(1).exampleImageId()).isEqualTo("8");
  }

  @Test
  @DisplayName("상세·요약 JSON 에 회원 식별자(memberId·email·username)가 없다")
  void detail_responseHasNoMemberId() {
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", "author-secret-id", NOW)));
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of("author-secret-id", "다른보호자"));

    String detailJson = JsonMapper.builder().build().writeValueAsString(service.detail(GUARDIAN, "p1"));
    when(talkPostRepository.findFeedPage(any(), any(), anyCollection(), any(), anyString(), any()))
      .thenReturn(List.of(post("p1", "author-secret-id", NOW)));
    String feedJson = JsonMapper.builder().build().writeValueAsString(service.feed(GUARDIAN, null, null, null, AppLocale.KO));

    for (String json : List.of(detailJson, feedJson)) {
      assertThat(json).doesNotContain("memberId", "email", "username", "author-secret-id");
      assertThat(json).contains("다른보호자");
    }
  }

  @Test
  @DisplayName("내가 올린 보이는 글을 원본 일과 id > 글 id 로 돌려준다")
  void mySharedPosts_mapsSourceRoutineToPost() {
    TalkPost shared = post("p1", "viewer-1", NOW);
    shared.setSourceRoutineId("routine-1");
    TalkPost orphan = post("p2", "viewer-1", NOW);
    orphan.setSourceRoutineId(null);
    when(talkPostRepository.findByAuthorMemberIdAndStatus("viewer-1", TalkPostStatus.VISIBLE))
      .thenReturn(List.of(shared, orphan));

    assertThat(service.mySharedPosts(GUARDIAN)).containsExactly(Map.entry("routine-1", "p1"));
  }

  @Test
  @DisplayName("내 글은 내 id 의 보이는 글만 조회하고 더 있으면 nextCursor 를 준다")
  void myPosts_queriesOwnVisiblePostsOnly_andReturnsNextCursor() {
    when(talkPostRepository.findMyPostsPage(eq("viewer-1"), eq(TalkPostStatus.VISIBLE), any(), anyString(), any()))
      .thenReturn(List.of(
        post("p1", "viewer-1", NOW.minusHours(1)),
        post("p2", "viewer-1", NOW.minusHours(2)),
        post("p3", "viewer-1", NOW.minusHours(3))));

    TalkFeedPageResponse page = service.myPosts(GUARDIAN, null, 2);

    assertThat(page.items()).extracting(TalkPostSummaryResponse::id).containsExactly("p1", "p2");
    assertThat(page.items()).allMatch(TalkPostSummaryResponse::isMine);
    assertThat(page.nextCursor()).isEqualTo(TalkCursor.encode(NOW.minusHours(2), "p2"));
  }

  @Test
  @DisplayName("내 글이 한 쪽 안에 끝나면 nextCursor 는 없다")
  void myPosts_lastPage_hasNoNextCursor() {
    when(talkPostRepository.findMyPostsPage(eq("viewer-1"), eq(TalkPostStatus.VISIBLE), any(), anyString(), any()))
      .thenReturn(List.of(post("p1", "viewer-1", NOW.minusHours(1))));

    TalkFeedPageResponse page = service.myPosts(GUARDIAN, null, null);

    assertThat(page.items()).hasSize(1);
    assertThat(page.nextCursor()).isNull();
  }

  @Test
  @DisplayName("그림은 보이는 글의 카드 그림 열쇠로 읽는다")
  void stepImage_readsByStoredKey() {
    ImageContent content = new ImageContent(new byte[] {1, 2}, "image/jpeg");
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", "author-1", NOW)));
    when(talkPostStepRepository.findByPostIdAndStepOrder("p1", 0))
      .thenReturn(Optional.of(step("p1", 0, "p1/0.jpg", null, null, false)));
    when(talkImageStorage.read("p1/0.jpg")).thenReturn(content);

    assertThat(service.stepImage(GUARDIAN, "p1", 0)).isSameAs(content);
  }

  @Test
  @DisplayName("글이 내려갔거나 그림 열쇠가 없으면 그림은 TALK_IMAGE_NOT_FOUND")
  void stepImage_hiddenPostOrNoKey_throwsImageNotFound() {
    TalkPost hidden = post("p1", "author-1", NOW);
    hidden.setStatus(TalkPostStatus.HIDDEN_BY_ADMIN);
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(hidden));
    when(talkPostRepository.findById("p2")).thenReturn(Optional.of(post("p2", "author-1", NOW)));
    when(talkPostStepRepository.findByPostIdAndStepOrder("p2", 0))
      .thenReturn(Optional.of(step("p2", 0, null, "7", null, false)));

    for (String postId : List.of("p1", "p2", "missing")) {
      assertThatThrownBy(() -> service.stepImage(GUARDIAN, postId, 0))
        .isInstanceOfSatisfying(CustomException.class,
          e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_IMAGE_NOT_FOUND));
    }
    verifyNoImageRead();
  }

  @Test
  @DisplayName("내가 차단한 글쓴이의 카드 그림은 TALK_IMAGE_NOT_FOUND 로 읽지 않는다")
  void stepImage_blockedAuthor_throwsImageNotFound() {
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", "author-blocked", NOW)));
    blockAuthor("author-blocked");

    assertThatThrownBy(() -> service.stepImage(GUARDIAN, "p1", 0))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_IMAGE_NOT_FOUND));
    verifyNoImageRead();
  }

  private void blockAuthor(String blockedMemberId) {
    TalkBlock block = new TalkBlock();
    block.setBlockerMemberId("viewer-1");
    block.setBlockedMemberId(blockedMemberId);
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of(block));
  }

  private void verifyNoImageRead() {
    org.mockito.Mockito.verifyNoInteractions(talkImageStorage);
  }

  private void assertNotFound(String postId) {
    assertThatThrownBy(() -> service.detail(GUARDIAN, postId))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
  }

  private static TalkPost post(String id, String authorMemberId, LocalDateTime createdAt) {
    TalkPost post = new TalkPost();
    post.setId(id);
    post.setAuthorMemberId(authorMemberId);
    post.setTitle("제목 " + id);
    post.setCategory(TalkCategory.DAILY_FLOW);
    post.setStatus(TalkPostStatus.VISIBLE);
    post.setStepCount(2);
    ReflectionTestUtils.setField(post, "createdAt", createdAt);
    return post;
  }

  private static TalkPostStep step(
    String postId, int stepOrder, String imageKey, String pictogramId, String exampleImageId, boolean isBlurred
  ) {
    TalkPostStep step = new TalkPostStep();
    step.setPostId(postId);
    step.setStepOrder(stepOrder);
    step.setDescription("설명 " + stepOrder);
    step.setImageKey(imageKey);
    step.setPictogramId(pictogramId);
    step.setExampleImageId(exampleImageId);
    step.setBlurred(isBlurred);
    return step;
  }
}
