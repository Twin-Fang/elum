package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.application.service.CreditSettlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * AI 가 만든 일과를 저장 직전에 다시 확인하고 저장한다 (다중 보호자 E17).
 *
 * <p>AI 생성은 20초 안팎이 걸리고 그동안 트랜잭션이 없다. 그 사이 보호자가 나가면(나가기·탈퇴) 나간
 * 사람의 일과가 남는다. 저장 직전에 이룸이 행을 잠그고 관계를 다시 본다 — 나가기도 같은 행을 먼저
 * 잠그므로 둘은 차례로 줄 선다.
 *
 * <p>크레딧 정산도 이 트랜잭션에서 한다 (#407). 정산이 실패하면 일과 저장도 함께 되돌아가고, 일과 저장이
 * 실패하면 정산도 남지 않는다 — "돈은 나갔는데 일과가 없다"나 "일과는 있는데 청구가 없다"가 생기지 않는다.
 *
 * <p>{@code RoutineService} 밖에 둔 이유는 자기 호출이 프록시를 타지 않아서다. 그 안에 두면 이
 * 메서드의 트랜잭션이 열리지 않는다.
 */
@Component
@RequiredArgsConstructor
public class RoutineCreationWriter {

  private final ProfileRepository profileRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineRepository routineRepository;
  private final CreditReservationService creditReservationService;

  /**
   * @param creditJobId 예약한 크레딧 작업. null 이면(크레딧 꺼짐) 정산하지 않는다
   * @param imageCount  카드에 실제로 붙은 AI 그림 수 — 청구 = 글 단가 + 그림 단가 × 이 수
   */
  @Transactional
  public SavedRoutine save(String memberId, String profileId, Routine routine, String creditJobId, int imageCount) {
    Profile profile = profileRepository.findByIdForUpdate(profileId)
      .orElseThrow(() -> new CustomException(ErrorCode.PROFILE_NOT_FOUND));
    profileAccessGuard.requireGuardianOf(memberId, profileId);

    routine.setProfile(profile);
    // 만든 사람만 승인·수정·삭제한다 (명세 4-2). 새 코드는 늘 채운다.
    routine.setCreatedBy(memberId);
    // 새 일과는 목록 맨 뒤에 붙는다 — 보호자가 순서를 바꾼 뒤에도 새 일과가 중간에 끼어들지 않게.
    // 잠근 뒤에 세야 두 사람이 동시에 만들어도 번호가 겹치지 않는다.
    routine.setDisplayOrder(routineRepository.maxDisplayOrder(profileId) + 1);
    Routine saved = routineRepository.save(routine);

    if (creditJobId == null) {
      return new SavedRoutine(saved, null);
    }
    // 저장 뒤에 정산한다 — 작업에 일과 id 를 남겨야 같은 멱등 키로 다시 오면 이 일과를 돌려줄 수 있다.
    int cardCount = saved.getSteps() == null ? 0 : saved.getSteps().size();
    CreditSettlement settlement =
      creditReservationService.settle(creditJobId, cardCount, imageCount, saved.getId(), null);
    return new SavedRoutine(saved, settlement);
  }

  /**
   * 이미 정산한 작업의 일과를 응답으로 돌려준다 (같은 멱등 키 재요청 — AI 를 다시 부르지 않는다).
   *
   * <p>응답을 트랜잭션 안에서 만든다. 단계 목록이 지연 로딩이라 밖에서 읽으면 터진다(open-in-view 꺼짐).
   * 그사이 일과를 지웠으면 404 — 앱은 새로 만들기로 돌아간다.
   *
   * <p>지금도 볼 수 있는지 다시 확인한다. 멱등 키는 계정에 묶여 있어, 만든 뒤 이룸이에서 나간 보호자가 같은
   * 키로 다시 보내면 확인 없이는 더 이상 연결되지 않은 이룸이의 일과를 받아 간다.
   */
  @Transactional(readOnly = true)
  public RoutineResponse loadSaved(Caller caller, String routineId) {
    if (routineId == null) {
      throw new CustomException(ErrorCode.ROUTINE_NOT_FOUND);
    }
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    profileAccessGuard.checkRoutine(caller, routine.getProfile().getId(), routine.getCreatedBy(), RoutineAction.VIEW);
    return RoutineResponse.from(routine);
  }

  /**
   * 저장 결과.
   *
   * @param settlement 크레딧 정산 결과. 크레딧이 꺼져 있으면 null
   */
  public record SavedRoutine(Routine routine, CreditSettlement settlement) {

  }
}
