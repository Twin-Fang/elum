package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
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
 * <p>{@code RoutineService} 밖에 둔 이유는 자기 호출이 프록시를 타지 않아서다. 그 안에 두면 이
 * 메서드의 트랜잭션이 열리지 않는다.
 */
@Component
@RequiredArgsConstructor
public class RoutineCreationWriter {

  private final ProfileRepository profileRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineRepository routineRepository;

  @Transactional
  public Routine save(String memberId, String profileId, Routine routine) {
    Profile profile = profileRepository.findByIdForUpdate(profileId)
      .orElseThrow(() -> new CustomException(ErrorCode.PROFILE_NOT_FOUND));
    profileAccessGuard.requireGuardianOf(memberId, profileId);

    routine.setProfile(profile);
    // 만든 사람만 승인·수정·삭제한다 (명세 4-2). 새 코드는 늘 채운다.
    routine.setCreatedBy(memberId);
    // 새 일과는 목록 맨 뒤에 붙는다 — 보호자가 순서를 바꾼 뒤에도 새 일과가 중간에 끼어들지 않게.
    // 잠근 뒤에 세야 두 사람이 동시에 만들어도 번호가 겹치지 않는다.
    routine.setDisplayOrder(routineRepository.maxDisplayOrder(profileId) + 1);
    return routineRepository.save(routine);
  }
}
