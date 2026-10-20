package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkFeedPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostDetailResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostDetailResponse.DetailStep;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostSummaryResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostSummaryResponse.StepThumb;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkCursor;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkHelpfulRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기 읽기: 피드, 인기, 상세, 카드 그림, 내가 나눈 일과 매핑
 * 보이는 글만, 차단한 보호자·정지 회원 글 제외, 응답에 회원 id·이메일 없음
 */
@Service
@Transactional(readOnly = true)
public class TalkFeedQueryService {

  static final int DEFAULT_PAGE_SIZE = 20;
  static final int MAX_PAGE_SIZE = 50;
  // cursor 없음: 어떤 글보다 늦은 시각 (cursor 조건을 항상 참으로 만듦)
  static final LocalDateTime NO_CURSOR_CREATED_AT = LocalDateTime.of(9999, 12, 31, 0, 0);
  // 한 쪽을 채우려고 차단·정지 글을 건너뛰며 다시 읽는 최대 횟수
  private static final int MAX_FEED_SCAN_ROUNDS = 5;
  // 요약에 싣는 앞쪽 카드 수 (stepOrder 0..3)
  private static final int PREVIEW_STEP_COUNT = 4;
  // 인기: 가져간 기록을 세는 기간(일), 최대 개수, 걸러내기 전에 읽는 후보 수
  private static final int POPULAR_WINDOW_DAYS = 7;
  private static final int POPULAR_MAX_COUNT = 10;
  private static final int POPULAR_CANDIDATE_COUNT = 50;

  private final TalkPostRepository talkPostRepository;
  private final TalkPostStepRepository talkPostStepRepository;
  private final TalkHelpfulRepository talkHelpfulRepository;
  private final TalkImportRepository talkImportRepository;
  private final TalkImageStorage talkImageStorage;
  private final MemberService memberService;
  private final TalkPostAccess talkPostAccess;
  private final Clock clock;

  @Autowired
  public TalkFeedQueryService(
    TalkPostRepository talkPostRepository, TalkPostStepRepository talkPostStepRepository,
    TalkHelpfulRepository talkHelpfulRepository, TalkImportRepository talkImportRepository,
    TalkImageStorage talkImageStorage, MemberService memberService, TalkPostAccess talkPostAccess
  ) {
    this(talkPostRepository, talkPostStepRepository, talkHelpfulRepository, talkImportRepository,
      talkImageStorage, memberService, talkPostAccess, Clock.systemDefaultZone());
  }

  // 테스트가 시계를 고정할 수 있게 둔다
  TalkFeedQueryService(
    TalkPostRepository talkPostRepository, TalkPostStepRepository talkPostStepRepository,
    TalkHelpfulRepository talkHelpfulRepository, TalkImportRepository talkImportRepository,
    TalkImageStorage talkImageStorage, MemberService memberService, TalkPostAccess talkPostAccess, Clock clock
  ) {
    this.talkPostRepository = talkPostRepository;
    this.talkPostStepRepository = talkPostStepRepository;
    this.talkHelpfulRepository = talkHelpfulRepository;
    this.talkImportRepository = talkImportRepository;
    this.talkImageStorage = talkImageStorage;
    this.memberService = memberService;
    this.talkPostAccess = talkPostAccess;
    this.clock = clock;
  }

  /**
   * 피드 한 쪽: 분류 확인 > 보이는 글·같은 언어 최신순 읽기 > 차단·정지 글 거르기 > size 만큼 자르고 nextCursor
   * cursor 형식이 틀리면 첫 쪽, size 는 1~50 (기본 20)
   */
  public TalkFeedPageResponse feed(Caller caller, String category, String cursor, Integer size, AppLocale viewerLocale) {
    List<TalkCategory> categories = categoriesOf(category);
    int pageSize = size == null ? DEFAULT_PAGE_SIZE : Math.clamp(size, 1, MAX_PAGE_SIZE);
    int fetchSize = pageSize + 1;
    Set<String> blockedAuthorIds = talkPostAccess.blockedAuthorIdsOf(caller);

    // 읽기 (한 건 더, 거른 만큼 부족하면 이어서 읽기)
    TalkCursor position = TalkCursor.decode(cursor).orElse(null);
    List<TalkPost> collected = new ArrayList<>();
    boolean isExhausted = false;
    for (int round = 0; round < MAX_FEED_SCAN_ROUNDS && collected.size() < fetchSize; round++) {
      List<TalkPost> batch = talkPostRepository.findFeedPage(TalkPostStatus.VISIBLE, viewerLocale, categories,
        position == null ? NO_CURSOR_CREATED_AT : position.createdAt(),
        position == null ? "" : position.id(), PageRequest.of(0, fetchSize));
      if (batch.isEmpty()) {
        isExhausted = true;
        break;
      }
      for (TalkPost post : talkPostAccess.readablePosts(caller, batch, blockedAuthorIds)) {
        if (collected.size() < fetchSize) {
          collected.add(post);
        }
      }
      TalkPost lastScanned = batch.get(batch.size() - 1);
      position = new TalkCursor(lastScanned.getCreatedAt(), lastScanned.getId());
      if (batch.size() < fetchSize) {
        isExhausted = true;
        break;
      }
    }

    // 자르기 > nextCursor (더 있을 때만, 거르다 끝난 경우는 읽은 마지막 위치에서 이어감)
    List<TalkPost> page = collected.size() > pageSize ? collected.subList(0, pageSize) : collected;
    String nextCursor = null;
    if (collected.size() > pageSize) {
      TalkPost last = page.get(page.size() - 1);
      nextCursor = TalkCursor.encode(last.getCreatedAt(), last.getId());
    } else if (!isExhausted && position != null) {
      nextCursor = TalkCursor.encode(position.createdAt(), position.id());
    }
    return new TalkFeedPageResponse(toSummaries(caller, page), nextCursor);
  }

  /**
   * 인기 글: 최근 7일 가져간 고유 보호자 수 내림차순 후보 > 차단·정지 글 거르기 > 최대 10개
   */
  public List<TalkPostSummaryResponse> popular(Caller caller, String category, AppLocale viewerLocale) {
    List<TalkCategory> categories = categoriesOf(category);
    LocalDateTime since = LocalDateTime.now(clock).minusDays(POPULAR_WINDOW_DAYS);
    List<String> rankedPostIds = talkPostRepository.findPopularPostIds(
      TalkPostStatus.VISIBLE, viewerLocale, categories, since, PageRequest.of(0, POPULAR_CANDIDATE_COUNT));
    if (rankedPostIds.isEmpty()) {
      return List.of();
    }

    // findAllById 는 순서를 보장하지 않아 조회 순서대로 다시 세움
    Map<String, TalkPost> postById = talkPostRepository.findAllById(rankedPostIds).stream()
      .collect(Collectors.toMap(TalkPost::getId, post -> post, (first, second) -> first));
    List<TalkPost> rankedPosts = rankedPostIds.stream().map(postById::get).filter(Objects::nonNull).toList();
    Set<String> blockedAuthorIds = talkPostAccess.blockedAuthorIdsOf(caller);
    List<TalkPost> page = talkPostAccess.readablePosts(caller, rankedPosts, blockedAuthorIds).stream()
      .limit(POPULAR_MAX_COUNT).toList();
    return toSummaries(caller, page);
  }

  /**
   * 글 상세: 보이는 글 확인 > 차단·정지 글쓴이 확인 > 카드·내 반응 (보이지 않으면 TALK_POST_NOT_FOUND)
   */
  public TalkPostDetailResponse detail(Caller caller, String postId) {
    TalkPost post = talkPostAccess.requireReadablePost(caller, postId);

    TalkPostSummaryResponse summary = toSummaries(caller, List.of(post), false).get(0);
    List<DetailStep> steps = talkPostStepRepository.findByPostIdOrderByStepOrderAsc(postId).stream()
      .map(step -> new DetailStep(step.getStepOrder(), step.getTitle(), step.getDescription(),
        step.getImageKey() != null, step.getPictogramId(), step.getExampleImageId(), step.isBlurred()))
      .toList();
    return new TalkPostDetailResponse(summary.id(), summary.authorNickname(), summary.isMine(), summary.title(),
      summary.category(), summary.stepCount(), summary.note(), summary.helpfulCount(), summary.commentCount(),
      summary.importCount(), summary.createdAt(), steps,
      talkHelpfulRepository.existsByPostIdAndMemberId(postId, caller.memberId()),
      talkImportRepository.existsByPostIdAndMemberId(postId, caller.memberId()));
  }

  /**
   * 카드 그림: 읽을 수 있는 글 확인 > 카드의 그림 열쇠 > 파일 읽기 (내려간·차단·정지 글, 열쇠 없음은 TALK_IMAGE_NOT_FOUND)
   */
  public ImageContent stepImage(Caller caller, String postId, int stepOrder) {
    Optional<TalkPost> post = talkPostAccess.findReadablePost(caller, postId);
    String imageKey = post.flatMap(found -> talkPostStepRepository.findByPostIdAndStepOrder(postId, stepOrder))
      .map(TalkPostStep::getImageKey)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_IMAGE_NOT_FOUND));
    return talkImageStorage.read(imageKey);
  }

  /**
   * 내가 나눈 보이는 글: 원본 일과 id > 글 id (원본이 없는 글은 빠짐)
   */
  public Map<String, String> mySharedPosts(Caller caller) {
    Map<String, String> postIdBySourceRoutineId = new LinkedHashMap<>();
    for (TalkPost post : talkPostRepository.findByAuthorMemberIdAndStatus(caller.memberId(), TalkPostStatus.VISIBLE)) {
      if (post.getSourceRoutineId() != null) {
        postIdBySourceRoutineId.putIfAbsent(post.getSourceRoutineId(), post.getId());
      }
    }
    return postIdBySourceRoutineId;
  }

  // 분류 비면 6개 전부, 모르는 값은 INVALID_INPUT_VALUE
  private static List<TalkCategory> categoriesOf(String category) {
    if (category == null || category.isBlank()) {
      return List.of(TalkCategory.values());
    }
    return List.of(TalkCategory.parse(category));
  }

  private List<TalkPostSummaryResponse> toSummaries(Caller caller, List<TalkPost> posts) {
    return toSummaries(caller, posts, true);
  }

  // 글 목록 > 요약 (닉네임·앞 4장 카드는 한 번에 읽음, 상세는 카드를 따로 읽으므로 앞 카드를 건너뜀)
  private List<TalkPostSummaryResponse> toSummaries(Caller caller, List<TalkPost> posts, boolean shouldIncludePreviewSteps) {
    if (posts.isEmpty()) {
      return List.of();
    }
    Set<String> authorIds = posts.stream().map(TalkPost::getAuthorMemberId).collect(Collectors.toSet());
    Map<String, String> nicknameByMemberId = memberService.nicknamesOf(authorIds);
    Map<String, List<StepThumb>> thumbsByPostId = shouldIncludePreviewSteps ? previewStepsByPostId(posts) : Map.of();
    return posts.stream()
      .map(post -> new TalkPostSummaryResponse(post.getId(), nicknameByMemberId.get(post.getAuthorMemberId()),
        post.getAuthorMemberId().equals(caller.memberId()), post.getTitle(), post.getCategory().name(),
        post.getStepCount(), thumbsByPostId.getOrDefault(post.getId(), List.of()), post.getNote(),
        post.getHelpfulCount(), post.getCommentCount(), post.getImportCount(), post.getCreatedAt()))
      .toList();
  }

  private Map<String, List<StepThumb>> previewStepsByPostId(List<TalkPost> posts) {
    Collection<String> postIds = posts.stream().map(TalkPost::getId).toList();
    Map<String, List<StepThumb>> thumbsByPostId = new HashMap<>();
    for (TalkPostStep step : talkPostStepRepository
      .findByPostIdInAndStepOrderLessThanOrderByStepOrderAsc(postIds, PREVIEW_STEP_COUNT)) {
      thumbsByPostId.computeIfAbsent(step.getPostId(), key -> new ArrayList<>())
        .add(new StepThumb(step.getStepOrder(), step.getImageKey() != null, step.getPictogramId(),
          step.getExampleImageId(), step.isBlurred()));
    }
    return thumbsByPostId;
  }
}
