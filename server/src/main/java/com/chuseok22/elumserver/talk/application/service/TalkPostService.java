package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.member.core.NicknamePolicy;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot.StepSnapshot;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPostCreateRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPreviewRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostCreatedResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPreviewResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPreviewResponse.PreviewStep;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기 올리기: 미리보기(이름 가린 글), 글 저장(카드 스냅샷, 그림 사본, 흐리게)
 * 일과·회원 데이터는 RoutineShareService·MemberService 로만 읽음, 글·그림 원문은 로그에 남기지 않음
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TalkPostService {

  // 흐리게 처리한 그림은 항상 JPEG
  private static final String BLURRED_CONTENT_TYPE = "image/jpeg";

  private final TalkPostRepository talkPostRepository;
  private final TalkPostStepRepository talkPostStepRepository;
  private final TalkImageStorage talkImageStorage;
  private final TalkImageBlurrer talkImageBlurrer;
  private final RoutineShareService routineShareService;
  private final MemberService memberService;
  private final NicknamePolicy nicknamePolicy;

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
   * 올리기: 규칙 동의 > 분류·한마디 정리 > 스냅샷 > 중복 확인 > 이름 가리기 > 금칙어 > 글 저장 > 카드·그림 저장
   */
  @Transactional
  public TalkPostCreatedResponse create(Caller caller, TalkPostCreateRequest request) {
    // 요청 검증 (규칙 동의, 분류, 한마디)
    if (!memberService.hasAgreedTalkRules(caller.memberId())) {
      throw new CustomException(ErrorCode.TALK_RULES_NOT_AGREED);
    }
    TalkCategory category = TalkCategory.parse(request.category());
    String note = TalkTextRules.normalizeNote(request.note());

    // 올릴 수 있는 일과인지 (스냅샷, 같은 원본 중복)
    RoutineShareSnapshot snapshot = snapshotOf(caller, request.routineId());
    if (talkPostRepository.existsBySourceRoutineIdAndStatus(snapshot.originalRoutineId(), TalkPostStatus.VISIBLE)) {
      throw new CustomException(ErrorCode.TALK_ALREADY_SHARED);
    }

    // 이름 가리기 > 금칙어 (가린 뒤 글 기준)
    MaskedPost masked = maskNames(snapshot, note);
    rejectBlockedWords(masked);

    // 글 저장 > 카드·그림 저장 (그림 단계 실패 시 쓴 파일 정리 후 롤백)
    TalkPost post = talkPostRepository.save(newPost(caller, snapshot, masked, category));
    Set<String> blurredStepIds = request.blurredStepIds() == null ? Set.of() : new HashSet<>(request.blurredStepIds());
    try {
      talkPostStepRepository.saveAll(newSteps(post.getId(), masked.steps(), blurredStepIds));
    } catch (RuntimeException e) {
      talkImageStorage.deletePost(post.getId());
      throw e;
    }
    log.info("[talk post] created : stepCount={}", post.getStepCount());
    return new TalkPostCreatedResponse(post.getId());
  }

  private RoutineShareSnapshot snapshotOf(Caller caller, String routineId) {
    if (routineId == null || routineId.isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return routineShareService.snapshotForShare(caller, routineId);
  }

  // 제목·카드 제목·카드 설명·한마디의 이룸이 호칭 > 자리표시 (실패하면 원문을 쓰지 않고 거절)
  private MaskedPost maskNames(RoutineShareSnapshot snapshot, String note) {
    try {
      String nickname = snapshot.profileNickname();
      List<MaskedStep> steps = snapshot.steps().stream()
        .map(step -> new MaskedStep(step,
          mask(step.title(), nickname, snapshot), mask(step.description(), nickname, snapshot)))
        .toList();
      return new MaskedPost(mask(snapshot.title(), nickname, snapshot), mask(note, nickname, snapshot), steps);
    } catch (RuntimeException e) {
      log.warn("[talk post] rejected 500 : nickname mask failed");
      throw new CustomException(ErrorCode.TALK_NICKNAME_MASK_FAILED);
    }
  }

  private static String mask(String text, String nickname, RoutineShareSnapshot snapshot) {
    return NicknamePlaceholder.mask(text, nickname, snapshot.language());
  }

  // 제목·한마디·카드 글에 욕설이 있으면 거절
  private void rejectBlockedWords(MaskedPost masked) {
    Stream<String> stepTexts = masked.steps().stream().flatMap(step -> Stream.of(step.title(), step.description()));
    boolean hasBlockedWord = Stream.concat(Stream.of(masked.title(), masked.note()), stepTexts)
      .anyMatch(nicknamePolicy::containsBlockedWord);
    if (hasBlockedWord) {
      log.warn("[talk post] rejected 400 : blocked word in text");
      throw new CustomException(ErrorCode.TALK_TEXT_NOT_ALLOWED);
    }
  }

  private static TalkPost newPost(Caller caller, RoutineShareSnapshot snapshot, MaskedPost masked,
    TalkCategory category) {
    TalkPost post = new TalkPost();
    post.setAuthorMemberId(caller.memberId());
    post.setSourceRoutineId(snapshot.originalRoutineId());
    post.setTitle(masked.title());
    post.setNote(masked.note());
    post.setCategory(category);
    post.setLanguage(snapshot.language());
    post.setStepCount(masked.steps().size());
    post.setStatus(TalkPostStatus.VISIBLE);
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
