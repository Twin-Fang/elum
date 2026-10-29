package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.notification.core.event.TalkPostImportedEvent;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft.DraftStep;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.request.TalkImportRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkImportResponse;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkImport;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기 가져가기: 보이는 글 확인, 카드·그림 초안, 일과관리 원본 만들기(일과 쪽), 가져간 기록과 횟수
 * 보호자 한 명당 글마다 첫 가져가기만 횟수에 셈
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TalkImportService {

  private final TalkPostAccess talkPostAccess;
  private final TalkPostRepository talkPostRepository;
  private final TalkPostStepRepository talkPostStepRepository;
  private final TalkImportRepository talkImportRepository;
  private final TalkBlockRepository talkBlockRepository;
  private final TalkImageStorage talkImageStorage;
  private final RoutineShareService routineShareService;
  private final ApplicationEventPublisher eventPublisher;

  /**
   * 가져가기: 요청 검증 > 읽을 수 있는 글(차단·정지 글쓴이 제외) > 카드·그림 초안 > 일과 만들기 위임 > 가져간 기록 > 첫 가져가기면 횟수 +1 > 글쓴이 알림 이벤트
   *
   * @throws CustomException 내렸거나 없거나 차단·정지 글쓴이의 글은 TALK_POST_NOT_FOUND, 이룸이·묶음 오류는 일과 쪽 예외 그대로
   */
  @Transactional
  public TalkImportResponse importToLibrary(Caller caller, String postId, TalkImportRequest request) {
    if (request == null || request.profileId() == null || request.profileId().isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    TalkPost post = talkPostAccess.requireReadablePost(caller, postId);

    RoutineImportDraft draft = toDraft(post, talkPostStepRepository.findByPostIdOrderByStepOrderAsc(post.getId()));
    String routineId = routineShareService.importToLibrary(caller, request.profileId(), request.groupId(), draft);

    // 이 보호자의 첫 가져가기 판정은 기록을 남기기 전에 (성공한 가져가기만 셈)
    boolean isFirstImportByMember = !talkImportRepository.existsByPostIdAndMemberId(post.getId(), caller.memberId());
    talkImportRepository.save(newImportRecord(post.getId(), caller.memberId(), request.profileId(), routineId));
    if (isFirstImportByMember) {
      talkPostRepository.increaseImportCount(post.getId());
      // 알림 이벤트는 보호자당 첫 가져가기만 (알림의 숫자 = 가져간 보호자 수), 글쓴이가 나를 차단했으면 내지 않음
      if (!talkBlockRepository.existsByBlockerMemberIdAndBlockedMemberId(post.getAuthorMemberId(), caller.memberId())) {
        eventPublisher.publishEvent(
          new TalkPostImportedEvent(post.getId(), post.getAuthorMemberId(), caller.memberId(), post.getTitle()));
      }
    }
    return new TalkImportResponse(routineId, request.profileId());
  }

  private RoutineImportDraft toDraft(TalkPost post, List<TalkPostStep> steps) {
    List<DraftStep> draftSteps = steps.stream()
      .map(step -> new DraftStep(step.getStepOrder(), step.getTitle(), step.getDescription(),
        step.getPictogramId(), step.getExampleImageId(), readImageOrNull(step.getImageKey())))
      .toList();
    return new RoutineImportDraft(post.getId(), post.getTitle(), post.getLanguage(), draftSteps);
  }

  // 그림 사본을 못 읽어도 카드는 가져감 (픽토그램·예시 이미지가 대신함)
  private ImageContent readImageOrNull(String imageKey) {
    if (imageKey == null) {
      return null;
    }
    try {
      return talkImageStorage.read(imageKey);
    } catch (RuntimeException e) {
      log.warn("[talk import] image read failed : card imported without image");
      return null;
    }
  }

  private TalkImport newImportRecord(String postId, String memberId, String profileId, String routineId) {
    TalkImport record = new TalkImport();
    record.setPostId(postId);
    record.setMemberId(memberId);
    record.setProfileId(profileId);
    record.setRoutineId(routineId);
    return record;
  }
}
