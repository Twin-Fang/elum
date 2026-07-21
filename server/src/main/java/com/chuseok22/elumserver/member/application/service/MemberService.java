package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberSupportGoalsUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberService {

  private final MemberRepository memberRepository;

  private final RoutineRepository routineRepository;

  public MemberResponse getMyInfo(String memberId) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
    return MemberResponse.from(member);
  }

  @Transactional
  public MemberResponse updateNickname(String memberId, MemberNicknameUpdateRequest request) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
    member.setNickname(request.nickname());
    return MemberResponse.from(member);
  }

  @Transactional
  public MemberResponse updateSupportGoals(String memberId, MemberSupportGoalsUpdateRequest request) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
    member.getSupportGoals().clear();
    member.getSupportGoals().addAll(request.supportGoals());
    return MemberResponse.from(member);
  }

  @Transactional
  public void withdraw(String memberId) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    List<Routine> routines = routineRepository.findAllByMemberId(memberId);
    routineRepository.deleteAll(routines);

    memberRepository.delete(member);
  }
}
