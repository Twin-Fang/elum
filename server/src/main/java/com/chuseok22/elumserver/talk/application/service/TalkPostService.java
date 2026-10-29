package com.chuseok22.elumserver.talk.application.service;

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
import com.chuseok22.elumserver.talk.application.dto.response.TalkPreviewResponse.PreviewStep;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkPostVisibility;
import com.chuseok22.elumserver.talk.core.TalkTextRules;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.image.TalkImageBlurrer;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 이야기 올리기·고치기·내리기: 미리보기(이름 가린 글), 글 저장(카드 스냅샷, 그림 사본, 흐리게), 한마디·분류 고치기, 글 내리기
 * 일과·회원 데이터는 RoutineShareService·MemberService 로만 읽음, 글·그림 원문은 로그에 남기지 않음
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TalkPostService {

  // 내린 글의 제목 (본문을 남기지 않음)
  private static final String DELETED_POST_TITLE = "";
  // 흐리게 처리한 그림은 항상 JPEG
  private static final String BLURRED_CONTENT_TYPE = "image/jpeg";
  // 남은 호칭을 문자열 그대로 치환하는 최소 호칭 길이 (코드포인트)
  private static final int MINIMUM_STRICT_MASK_NAME_LENGTH = 2;

  private final TalkPostRepository talkPostRepository;
  private final TalkPostStepRepository talkPostStepRepository;
  private final TalkImageStorage talkImageStorage;
  private final TalkImageBlurrer talkImageBlurrer;
  private final RoutineShareService routineShareService;
  private final MemberService memberService;
  private final NicknamePolicy nicknamePolicy;
  private final TalkFeedQueryService talkFeedQueryService;

  /**
   * 미리보기: 스냅샷 > 이름 가리기 > 가린 글과 사진 카드 여부 (저장 없음)
   */
  @Transactional(readOnly = true)
  public TalkPreviewResponse preview(Caller caller, TalkPreviewRequest request) {
    RoutineShareSnapshot snapshot = snapshotOf(caller, request == null ? null : request.routineId());
    MaskedPost masked = maskNames(snapshot, null);
    List<PreviewStep> previewSteps = masked.steps().stream()
      .map(step -> new PreviewStep(step.source().stepId(), step.source().stepOrder(), step.title(),
        step.description(), step.source().isGuardianPhoto()))
      .toList();
    return new TalkPreviewResponse(masked.title(), previewSteps, snapshot.hasGuardianPhoto());
  }

  /**
   * 올리기: 규칙 동의 > 분류·한마디 정리 > 스냅샷 > 중복 확인 > 스냅샷 글 저장
   */
  @Transactional
  public TalkPostCreatedResponse create(Caller caller, TalkPostCreateRequest request) {
    // 요청 검증 (규칙 동의, 분류, 한마디)
    if (!memberService.hasAgreedTalkRules(caller.memberId())) {
      throw new CustomException(ErrorCode.TALK_RULES_NOT_AGREED);
    }
    TalkCategory category = TalkCategory.parse(request.category());
    String note = TalkTextRules.normalizeNote(request.note());

    // 올릴 수 있는 일과인지 (스냅샷, 같은 원본의 공개 글 중복)
    RoutineShareSnapshot snapshot = snapshotOf(caller, request.routineId());
    if (talkPostRepository.existsBySourceRoutineIdAndStatusAndVisibility(
      snapshot.originalRoutineId(), TalkPostStatus.VISIBLE, TalkPostVisibility.PUBLIC)) {
      throw new CustomException(ErrorCode.TALK_ALREADY_SHARED);
    }

    TalkPost post = saveSnapshotPost(caller, snapshot,
      new SnapshotPostOptions(category, note, TalkPostVisibility.PUBLIC, request.blurredStepIds()));
    log.info("[talk post] created : stepCount={}", post.getStepCount());
    return new TalkPostCreatedResponse(post.getId());
  }

  /**
   * 스냅샷 글 저장 (공개 글·링크 글 공통): 이름 가리기 > 금칙어 > 글 저장 > 카드·그림 저장
   * 호출부가 권한·중복을 확인한 뒤 부름, 호출부 트랜잭션 안에서 돎 (그림 단계 실패 시 쓴 파일 정리 후 예외)
   */
  public TalkPost saveSnapshotPost(Caller caller, RoutineShareSnapshot snapshot, SnapshotPostOptions options) {
    // 이름 가리기 > 금칙어 (가린 뒤 글 기준)
    MaskedPost masked = maskNames(snapshot, options.note());
    rejectBlockedWords(masked);

    // 글 저장 > 카드·그림 저장
    TalkPost post = saveNewPost(newPost(caller, snapshot, masked, options));
    Set<String> blurredStepIds = options.blurredStepIds() == null ? Set.of() : new HashSet<>(options.blurredStepIds());
    try {
      talkPostStepRepository.saveAll(newSteps(post.getId(), masked.steps(), blurredStepIds));
    } catch (RuntimeException e) {
      deleteWrittenImagesQuietly(post.getId());
      throw e;
    }
    return post;
  }

  /**
   * 스냅샷 글 선택값: 분류(링크 글은 null), 한마디(없으면 null), 공개 범위, 흐리게 고른 카드 id(없으면 null)
   */
  public record SnapshotPostOptions(
    TalkCategory category, String note, TalkPostVisibility visibility, List<String> blurredStepIds) {

  }

  /**
   * 고치기: 입력 확인 > 내 글 확인 > 분류 > 한마디(정리, 이름 가리기, 금칙어) > 저장 > 상세
   * 보낸 항목만 바꿈, 한마디는 빈 값이면 지움, 원본 일과가 지워졌으면 호칭 없이(글 그대로) 가림
   */
  @Transactional
  public TalkPostDetailResponse update(Caller caller, String postId, TalkPostUpdateRequest request) {
    // 요청 검증 (바꿀 항목 있음)
    if (request == null || (request.note() == null && request.category() == null)) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    TalkPost post = findOwnVisiblePost(caller, postId);

    // 분류 > 한마디 (이룸이 호칭 가리기, 가린 뒤 금칙어)
    if (request.category() != null) {
      post.setCategory(TalkCategory.parse(request.category()));
    }
    if (request.note() != null) {
      post.setNote(maskedNoteOf(post, request.note()));
    }
    talkPostRepository.saveAndFlush(post);
    log.info("[talk post] updated : postId={}", postId);
    return talkFeedQueryService.detail(caller, postId);
  }

  /**
   * 내리기: 내 글 확인 > 제목·한마디 비움 + DELETED > 카드 삭제 > 커밋 뒤 그림 파일 삭제 (같은 원본은 다시 올릴 수 있음)
   */
  @Transactional
  public void delete(Caller caller, String postId) {
    TalkPost post = findOwnVisiblePost(caller, postId);
    // 개인정보처리방침: 내린 글의 본문은 남기지 않음 (title 은 NOT NULL 이라 빈 문자열)
    post.setTitle(DELETED_POST_TITLE);
    post.setNote(null);
    post.setStatus(TalkPostStatus.DELETED);
    talkPostRepository.saveAndFlush(post);
    talkPostStepRepository.deleteAllByPostId(postId);
    deleteImagesAfterCommit(postId);
    log.info("[talk post] deleted : postId={}", postId);
  }

  // 없거나 이미 내린 글은 NOT_FOUND, 남의 글은 NOT_AUTHOR
  private TalkPost findOwnVisiblePost(Caller caller, String postId) {
    TalkPost post = talkPostRepository.findById(postId)
      .filter(found -> found.getStatus() == TalkPostStatus.VISIBLE)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_POST_NOT_FOUND));
    if (!post.getAuthorMemberId().equals(caller.memberId())) {
      log.warn("[talk post] rejected 403 : not the author");
      throw new CustomException(ErrorCode.TALK_NOT_AUTHOR);
    }
    return post;
  }

  // 한마디 정리 > 이름 가리기 > 금칙어 (빈 값은 null = 지움)
  private String maskedNoteOf(TalkPost post, String rawNote) {
    String note = TalkTextRules.normalizeNote(rawNote);
    if (note == null) {
      return null;
    }
    String nickname = routineShareService.findProfileNickname(post.getSourceRoutineId());
    String maskedNote;
    try {
      maskedNote = mask(note, nickname, post.getLanguage());
    } catch (RuntimeException e) {
      log.warn("[talk post] rejected 500 : nickname mask failed");
      throw new CustomException(ErrorCode.TALK_NICKNAME_MASK_FAILED);
    }
    if (hasRemainingNickname(Stream.of(maskedNote), nickname, post.getLanguage())) {
      log.warn("[talk post] rejected 500 : nickname remains after mask");
      throw new CustomException(ErrorCode.TALK_NICKNAME_MASK_FAILED);
    }
    rejectBlockedWords(Stream.of(maskedNote));
    return maskedNote;
  }

  // 커밋 뒤에만 그림 삭제 (롤백되면 글이 남으므로), 트랜잭션 밖이면 바로
  private void deleteImagesAfterCommit(String postId) {
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      deleteWrittenImagesQuietly(postId);
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCommit() {
        deleteWrittenImagesQuietly(postId);
      }
    });
  }

  private RoutineShareSnapshot snapshotOf(Caller caller, String routineId) {
    if (routineId == null || routineId.isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return routineShareService.snapshotForShare(caller, routineId);
  }

  // 저장 + 즉시 반영: 같은 원본·공개 범위의 보이는 글이 동시에 올라오면 V59 부분 유니크 인덱스가 막음 > TALK_ALREADY_SHARED
  private TalkPost saveNewPost(TalkPost post) {
    try {
      return talkPostRepository.saveAndFlush(post);
    } catch (DataIntegrityViolationException e) {
      log.warn("[talk post] rejected 409 : same routine shared concurrently");
      throw new CustomException(ErrorCode.TALK_ALREADY_SHARED);
    }
  }

  // 그림 정리 실패가 원래 예외를 가리지 않게 삼키고 로그만 남김
  private void deleteWrittenImagesQuietly(String postId) {
    try {
      talkImageStorage.deletePost(postId);
    } catch (RuntimeException cleanupFailure) {
      log.warn("[talk post] image cleanup failed : postId={}", postId, cleanupFailure);
    }
  }

  // 제목·카드 제목·카드 설명·한마디의 이룸이 호칭 > 자리표시 (실패하거나 호칭이 남으면 원문을 쓰지 않고 거절)
  private MaskedPost maskNames(RoutineShareSnapshot snapshot, String note) {
    MaskedPost masked;
    try {
      String nickname = snapshot.profileNickname();
      List<MaskedStep> steps = snapshot.steps().stream()
        .map(step -> new MaskedStep(step, mask(step.title(), nickname, snapshot.language()),
          mask(step.description(), nickname, snapshot.language())))
        .toList();
      masked = new MaskedPost(mask(snapshot.title(), nickname, snapshot.language()),
        mask(note, nickname, snapshot.language()), steps);
    } catch (RuntimeException e) {
      log.warn("[talk post] rejected 500 : nickname mask failed");
      throw new CustomException(ErrorCode.TALK_NICKNAME_MASK_FAILED);
    }
    if (hasRemainingNickname(masked, snapshot)) {
      log.warn("[talk post] rejected 500 : nickname remains after mask");
      throw new CustomException(ErrorCode.TALK_NICKNAME_MASK_FAILED);
    }
    return masked;
  }

  // 조사 규칙 가리기 > 남은 호칭 문자열 전부 치환 (예: "하늘색" 처럼 낱말 일부로 남은 것)
  private static String mask(String text, String nickname, AppLocale language) {
    String masked = NicknamePlaceholder.mask(text, nickname, language);
    if (masked == null || !isStrictMaskTarget(nickname, language)) {
      return masked;
    }
    return masked.replace(nickname.trim(), NicknamePlaceholder.placeholderFor(language));
  }

  // 호칭 2자 이상만 (1자는 오탐이 커서 제외), 자리표시가 호칭을 품으면 구분할 수 없어 제외
  private static boolean isStrictMaskTarget(String nickname, AppLocale language) {
    if (nickname == null) {
      return false;
    }
    String name = nickname.trim();
    return name.codePointCount(0, name.length()) >= MINIMUM_STRICT_MASK_NAME_LENGTH
      && !NicknamePlaceholder.placeholderFor(language).contains(name);
  }

  private static boolean hasRemainingNickname(MaskedPost masked, RoutineShareSnapshot snapshot) {
    return hasRemainingNickname(allTextsOf(masked), snapshot.profileNickname(), snapshot.language());
  }

  private static boolean hasRemainingNickname(Stream<String> texts, String nickname, AppLocale language) {
    if (!isStrictMaskTarget(nickname, language)) {
      return false;
    }
    String name = nickname.trim();
    return texts.anyMatch(text -> text != null && text.contains(name));
  }

  // 제목·한마디·카드 제목·카드 설명
  private static Stream<String> allTextsOf(MaskedPost masked) {
    Stream<String> stepTexts = masked.steps().stream().flatMap(step -> Stream.of(step.title(), step.description()));
    return Stream.concat(Stream.of(masked.title(), masked.note()), stepTexts);
  }

  // 제목·한마디·카드 글에 욕설이 있으면 거절
  private void rejectBlockedWords(MaskedPost masked) {
    rejectBlockedWords(allTextsOf(masked));
  }

  private void rejectBlockedWords(Stream<String> texts) {
    boolean hasBlockedWord = texts.anyMatch(nicknamePolicy::containsBlockedWord);
    if (hasBlockedWord) {
      log.warn("[talk post] rejected 400 : blocked word in text");
      throw new CustomException(ErrorCode.TALK_TEXT_NOT_ALLOWED);
    }
  }

  private static TalkPost newPost(Caller caller, RoutineShareSnapshot snapshot, MaskedPost masked,
    SnapshotPostOptions options) {
    TalkPost post = new TalkPost();
    post.setAuthorMemberId(caller.memberId());
    post.setSourceRoutineId(snapshot.originalRoutineId());
    post.setTitle(masked.title());
    post.setNote(masked.note());
    post.setCategory(options.category());
    post.setLanguage(snapshot.language());
    post.setStepCount(masked.steps().size());
    post.setStatus(TalkPostStatus.VISIBLE);
    post.setVisibility(options.visibility());
    return post;
  }

  // 카드별 스냅샷 저장: 글 순서는 0부터, 그림은 글 전용 사본으로 복사
  private List<TalkPostStep> newSteps(String postId, List<MaskedStep> maskedSteps, Set<String> blurredStepIds) {
    List<TalkPostStep> steps = new ArrayList<>(maskedSteps.size());
    for (int stepOrder = 0; stepOrder < maskedSteps.size(); stepOrder++) {
      MaskedStep masked = maskedSteps.get(stepOrder);
      TalkPostStep step = new TalkPostStep();
      step.setPostId(postId);
      step.setStepOrder(stepOrder);
      step.setTitle(masked.title());
      step.setDescription(masked.description());
      step.setPictogramId(masked.source().pictogramId());
      step.setExampleImageId(masked.source().exampleImageId());
      copyImage(postId, stepOrder, masked.source(), blurredStepIds, step);
      steps.add(step);
    }
    return steps;
  }

  // 그림 사본: 읽기 실패는 그림 없이 계속, 흐리게 고른 사진은 사본에만 블러 (흐리지 못하면 원본을 올리지 않고 예외)
  private void copyImage(String postId, int stepOrder, StepSnapshot source, Set<String> blurredStepIds,
    TalkPostStep step) {
    ImageContent original = routineShareService.readImage(source.imageKey());
    if (original == null) {
      return;
    }
    byte[] bytes = original.bytes();
    String contentType = original.contentType();
    // 사진이 아닌 카드 id 는 무시
    boolean isBlurTarget = source.isGuardianPhoto() && blurredStepIds.contains(source.stepId());
    if (isBlurTarget) {
      bytes = talkImageBlurrer.blur(bytes);
      contentType = BLURRED_CONTENT_TYPE;
    }
    step.setImageKey(talkImageStorage.save(postId, stepOrder, bytes, contentType));
    step.setBlurred(isBlurTarget);
  }

  private record MaskedPost(String title, String note, List<MaskedStep> steps) {

  }

  private record MaskedStep(StepSnapshot source, String title, String description) {

  }
}
