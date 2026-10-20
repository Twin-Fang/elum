package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft.DraftStep;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot.StepSnapshot;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineGroup;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineGroupRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기용 일과 입구: 공유 읽기(권한, 오늘 일과 > 원본, 공유 불가 판정, 카드 스냅샷, 그림 읽기)와 가져오기(일과관리 원본 만들기)
 * 일과·그림 저장소를 직접 쓰는 곳은 이 서비스뿐 (talk 는 여기만 거침)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineShareService {

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineImageStorage routineImageStorage;
  private final RoutineGroupRepository routineGroupRepository;
  private final RoutineGroupMembership routineGroupMembership;
  private final RoutineLibraryOrderService routineLibraryOrderService;
  private final RoutineStepSpeechQueue routineStepSpeechQueue;

  /**
   * 공유할 일과 스냅샷: 권한 확인 > 원본 찾기(오늘 일과면 sourceRoutineId) > 공유 불가 거절 > 카드 스냅샷
   *
   * @throws CustomException 공유 불가는 TALK_ROUTINE_NOT_SHAREABLE, 권한·없는 일과는 일과 접근 오류
   */
  @Transactional(readOnly = true)
  public RoutineShareSnapshot snapshotForShare(Caller caller, String routineId) {
    Routine requested = RoutineRules.routineFor(
      routineRepository, profileAccessGuard, caller, routineId, RoutineAction.VIEW);
    Routine original = resolveOriginal(caller, requested);
    if (!isShareable(original)) {
      log.info("[talk share] rejected : routine is not shareable");
      throw new CustomException(ErrorCode.TALK_ROUTINE_NOT_SHAREABLE);
    }
    return new RoutineShareSnapshot(
      original.getId(),
      original.getTitle(),
      original.getLanguage(),
      original.getProfile().getNickname(),
      original.getSteps().stream().map(RoutineShareService::toStepSnapshot).toList());
  }

  /**
   * 일과의 이룸이 호칭 (글 고치기 때 한마디 이름 가리기용): 일과가 지워졌으면 null, 권한 확인 없음(글쓴이 확인은 호출부)
   */
  @Transactional(readOnly = true)
  public String findProfileNickname(String routineId) {
    if (routineId == null) {
      return null;
    }
    return routineRepository.findById(routineId)
      .map(routine -> routine.getProfile().getNickname())
      .orElse(null);
  }

  /**
   * 일과 그림 읽기 (없거나 읽기 실패는 null, 던지지 않음)
   */
  public ImageContent readImage(String imageKey) {
    if (imageKey == null) {
      return null;
    }
    try {
      return routineImageStorage.read(imageKey);
    } catch (RuntimeException e) {
      log.warn("[talk share] image read failed : card image skipped");
      return null;
    }
  }

  /**
   * 이야기에서 일과관리로 가져오기: 권한 > 묶음 확인 > 원본 만들기 > 자리 정하기 > 저장 > 카드 그림 저장
   * 묶음 없이는 맨 앞, 묶음이면 그 묶음 맨 뒤. 그림 저장에 실패한 카드는 그림 없이 둠
   *
   * @return 만든 일과 id
   * @throws CustomException 연결 없는 이룸이는 PROFILE_ACCESS_DENIED, 이 이룸이 것이 아닌 묶음은 INVALID_INPUT_VALUE
   */
  @Transactional
  public String importToLibrary(Caller caller, String profileId, String groupId, RoutineImportDraft draft) {
    // 요청 검증 (이룸이 연결, 묶음 소속)
    Profile profile = profileAccessGuard.profileFor(Caller.guardian(caller.memberId(), profileId), ProfileAction.MANAGE);
    RoutineGroup group = groupId == null ? null : requireGroupOf(profile, groupId);

    Routine routine = newImportedRoutine(caller, profile, draft);
    // 자리 (묶음 맨 뒤 또는 일과관리 맨 앞)
    if (group == null) {
      routineLibraryOrderService.makeRoomAtFront(profile.getId());
      routine.setLibraryOrder(0);
    } else {
      List<Routine> orderedMembers = new ArrayList<>(routineGroupMembership.membersOf(group.getId()));
      orderedMembers.add(routine);
      routineGroupMembership.assign(group.getId(), orderedMembers);
    }
    Routine saved = RoutineRules.saveWithSpeech(routineRepository, routineStepSpeechQueue, routine);
    attachImportedImages(saved, draft);
    return saved.getId();
  }

  // 이 이룸이의 묶음이 아니거나 없는 묶음은 같은 400
  private RoutineGroup requireGroupOf(Profile profile, String groupId) {
    return routineGroupRepository.findById(groupId)
      .filter(group -> group.getProfile().getId().equals(profile.getId()))
      .orElseThrow(() -> {
        log.info("[talk import] rejected 400 : group is not of this profile, profileId={}", profile.getId());
        return new CustomException(ErrorCode.INVALID_INPUT_VALUE);
      });
  }

  // 저장 전 일과관리 원본 (보낸 상태, 홈에 안 뜸, 원문 칸은 제목)
  private Routine newImportedRoutine(Caller caller, Profile profile, RoutineImportDraft draft) {
    Routine routine = new Routine();
    routine.setProfile(profile);
    routine.setCreatedBy(caller.memberId());
    routine.setRawInputText(draft.title());
    routine.setSanitizedInputText(draft.title());
    routine.setTitle(draft.title());
    routine.setLanguage(draft.language());
    routine.setScheduledAt(LocalDateTime.now());
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setLibraryOnly(true);
    routine.setSourceRoutineId(null);
    routine.setTalkPostId(draft.talkPostId());
    List<RoutineStep> steps = new ArrayList<>();
    for (DraftStep draftStep : draft.steps()) {
      RoutineStep step = new RoutineStep();
      step.setRoutine(routine);
      step.setStepOrder(draftStep.stepOrder());
      step.setTitle(draftStep.title());
      step.setDescription(draftStep.description());
      step.setPictogramId(draftStep.pictogramId());
      step.setExampleImageId(draftStep.exampleImageId());
      step.setCompleted(false);
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }

  // 카드 id 가 생긴 뒤 그림 열쇠 넣기 (카드 순서 = 초안 순서, 실패한 카드는 그림 없이 둠)
  private void attachImportedImages(Routine saved, RoutineImportDraft draft) {
    for (int index = 0; index < draft.steps().size(); index++) {
      ImageContent image = draft.steps().get(index).image();
      if (image == null) {
        continue;
      }
      RoutineStep step = saved.getSteps().get(index);
      try {
        step.setImagePath(routineImageStorage.saveImported(step.getId(), image));
      } catch (RuntimeException e) {
        log.warn("[talk import] image save failed : card kept without image, stepOrder={}", step.getStepOrder());
      }
    }
  }

  // 오늘 일과 복사본 > 원본 (원본을 못 찾으면 공유 불가, 원본에도 같은 권한 확인)
  private Routine resolveOriginal(Caller caller, Routine requested) {
    String sourceRoutineId = requested.getSourceRoutineId();
    if (sourceRoutineId == null) {
      return requested;
    }
    Routine original = routineRepository.findById(sourceRoutineId)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_ROUTINE_NOT_SHAREABLE));
    profileAccessGuard.checkRoutine(
      caller, original.getProfile().getId(), original.getCreatedBy(), RoutineAction.VIEW);
    return original;
  }

  // 공유 불가 4개: 예시, 일과관리에서 지움, 이야기에서 가져온 일과(재공유 금지), 승인 전
  private static boolean isShareable(Routine original) {
    boolean isExample = Boolean.TRUE.equals(original.getIsExample());
    boolean isImportedFromTalk = original.getTalkPostId() != null;
    boolean isPendingReview = original.getStatus() == RoutineStatus.PENDING_REVIEW;
    return !isExample && !original.isLibraryHidden() && !isImportedFromTalk && !isPendingReview;
  }

  private static StepSnapshot toStepSnapshot(RoutineStep step) {
    return new StepSnapshot(
      step.getId(),
      step.getStepOrder(),
      step.getTitle(),
      step.getDescription(),
      step.getImagePath(),
      step.getPictogramId(),
      step.getExampleImageId(),
      RoutineImageStorage.isGuardianUploadedPhoto(step.getImagePath()));
  }
}
