package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.talk.application.dto.request.TalkLinkCreateRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkLinkResponse;
import com.chuseok22.elumserver.talk.application.service.TalkPostService.SnapshotPostOptions;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkPostVisibility;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 일과를 링크로 보내기: 링크 글 만들기(켜진 링크가 있으면 재사용), 내 링크 목록
 * 링크 글 = 공개 범위 LINK_ONLY 인 이야기 글 (가리기·흐리게·스냅샷·/s/ 페이지·가져가기를 이야기와 함께 씀), 끄기는 글 내리기
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TalkLinkService {

  private final TalkPostRepository talkPostRepository;
  private final TalkPostService talkPostService;
  private final RoutineShareService routineShareService;

  /**
   * 링크 만들기: 입력 확인 > 스냅샷(내가 만든 공유 가능 일과) > 켜진 링크 있으면 그대로 > 없으면 링크 글 저장
   * 분류·한마디·이용 규칙 동의를 받지 않음 (피드에 오르지 않는 글)
   *
   * @throws CustomException 남이 만든 일과 TALK_LINK_ROUTINE_NOT_MINE, 공유 불가 TALK_LINK_ROUTINE_NOT_SHAREABLE,
   *                         동시에 두 번 만들면 TALK_ALREADY_SHARED
   */
  @Transactional
  public TalkLinkResponse create(Caller caller, TalkLinkCreateRequest request) {
    String routineId = request == null ? null : request.routineId();
    if (routineId == null || routineId.isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    RoutineShareSnapshot snapshot = routineShareService.snapshotForLinkShare(caller, routineId);

    // 같은 원본의 켜진 링크 (두 번 눌러도 링크는 하나)
    Optional<TalkPost> activeLink = talkPostRepository.findFirstBySourceRoutineIdAndStatusAndVisibility(
      snapshot.originalRoutineId(), TalkPostStatus.VISIBLE, TalkPostVisibility.LINK_ONLY);
    if (activeLink.isPresent()) {
      log.info("[talk link] reused : postId={}", activeLink.get().getId());
      return new TalkLinkResponse(activeLink.get().getId(), true);
    }

    TalkPost post = talkPostService.saveSnapshotPost(caller, snapshot,
      new SnapshotPostOptions(null, null, TalkPostVisibility.LINK_ONLY, request.blurredStepIds()));
    log.info("[talk link] created : postId={}, stepCount={}", post.getId(), post.getStepCount());
    return new TalkLinkResponse(post.getId(), false);
  }

  /**
   * 내 켜진 링크: 원본 일과 id > 링크 글 id (원본이 없는 글은 빠짐)
   */
  @Transactional(readOnly = true)
  public Map<String, String> myLinks(Caller caller) {
    Map<String, String> postIdBySourceRoutineId = new LinkedHashMap<>();
    for (TalkPost post : talkPostRepository.findByAuthorMemberIdAndStatusAndVisibility(
      caller.memberId(), TalkPostStatus.VISIBLE, TalkPostVisibility.LINK_ONLY)) {
      if (post.getSourceRoutineId() != null) {
        postIdBySourceRoutineId.putIfAbsent(post.getSourceRoutineId(), post.getId());
      }
    }
    return postIdBySourceRoutineId;
  }
}
