package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.dto.request.GuardianNicknameUpdateRequest;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;

@ExtendWith(MockitoExtension.class)
class MemberServiceGuardianNicknameTest {

  @Mock private MemberRepository memberRepository;
  @Mock private GuardianNicknameChangeService guardianNicknameChangeService;
  // 쓰지 않는 의존성 — InjectMocks 가 생성자를 채우게 목으로 둔다.
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private GuardianshipService guardianshipService;

  @InjectMocks private MemberService memberService;

  // 깨지면: 두 보호자가 같은 이름을 동시에 저장할 때 500 이 나고 오류 코드가 사라짐
  @Test
  void 동시_저장으로_유니크_인덱스가_거부하면_중복_오류로_바꾼다() {
    Member member = new Member();
    member.setId("member-1");
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));
    when(memberRepository.saveAndFlush(eq(member))).thenThrow(new DataIntegrityViolationException("uk_member_nickname"));

    assertThatThrownBy(() -> memberService.updateGuardianNickname(
      Caller.guardian("member-1"), new GuardianNicknameUpdateRequest("푸른하늘")))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.NICKNAME_DUPLICATED);
  }

  @Test
  void 판정에서_막히면_저장하지_않고_그대로_던진다() {
    Member member = new Member();
    member.setId("member-1");
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));
    org.mockito.Mockito.doThrow(new CustomException(ErrorCode.NICKNAME_NOT_ALLOWED))
      .when(guardianNicknameChangeService).change(any(Member.class), eq("관리자"));

    assertThatThrownBy(() -> memberService.updateGuardianNickname(
      Caller.guardian("member-1"), new GuardianNicknameUpdateRequest("관리자")))
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.NICKNAME_NOT_ALLOWED);
    org.mockito.Mockito.verify(memberRepository, org.mockito.Mockito.never()).saveAndFlush(any());
  }
}
