package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
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
public class AdminMemberService {

  private final MemberRepository memberRepository;
  private final RoutineRepository routineRepository;

  public List<AdminMemberResponse> getAll() {
    return memberRepository.findAll().stream()
      .map(AdminMemberResponse::from)
      .toList();
  }

  public AdminMemberDetailResponse getDetail(String memberId) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
    List<Routine> routines = routineRepository.findAllByMemberId(memberId);
    return AdminMemberDetailResponse.of(member, routines);
  }

  public long count() {
    return memberRepository.count();
  }
}
