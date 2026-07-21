package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class MemberServiceTest {

  @Mock
  private MemberRepository memberRepository;

  @Mock
  private RoutineRepository routineRepository;

  @InjectMocks
  private MemberService memberService;

  @Test
  @DisplayName("탈퇴 시 연관 일과를 먼저 삭제한 뒤 회원을 삭제한다")
  void withdraw_withRoutines_deletesRoutinesThenMember() {
    Member member = new Member();
    member.setId("member-1");
    Routine routine = new Routine();
    routine.setId("routine-1");
    List<Routine> routines = List.of(routine);
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));
    when(routineRepository.findAllByMemberId("member-1")).thenReturn(routines);

    memberService.withdraw("member-1");

    InOrder callOrder = inOrder(routineRepository, memberRepository);
    callOrder.verify(routineRepository).deleteAll(routines);
    callOrder.verify(memberRepository).delete(member);
  }

  @Test
  @DisplayName("연관 일과가 없는 회원도 정상적으로 탈퇴된다")
  void withdraw_noRoutines_deletesMemberOnly() {
    Member member = new Member();
    member.setId("member-2");
    when(memberRepository.findById("member-2")).thenReturn(Optional.of(member));
    when(routineRepository.findAllByMemberId("member-2")).thenReturn(List.of());

    memberService.withdraw("member-2");

    verify(routineRepository).deleteAll(List.of());
    verify(memberRepository).delete(member);
  }

  @Test
  @DisplayName("존재하지 않는 회원을 탈퇴 시도하면 MEMBER_NOT_FOUND를 던진다")
  void withdraw_missingMember_throwsMemberNotFound() {
    when(memberRepository.findById("missing")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> memberService.withdraw("missing"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_NOT_FOUND));
  }
}
