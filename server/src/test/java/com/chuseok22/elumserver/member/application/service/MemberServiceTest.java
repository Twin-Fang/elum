package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.dto.request.MemberCharacterUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
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
  private ProfileRepository profileRepository;

  @Mock
  private RoutineRepository routineRepository;

  @Mock
  private AuthIdentityRepository authIdentityRepository;

  @Mock
  private RefreshTokenRepository refreshTokenRepository;

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
    when(routineRepository.findAllByProfileMemberId("member-1")).thenReturn(routines);

    memberService.withdraw("member-1");

    InOrder callOrder = inOrder(
      routineRepository, profileRepository, authIdentityRepository, refreshTokenRepository, memberRepository);
    callOrder.verify(routineRepository).deleteAll(routines);
    callOrder.verify(profileRepository).deleteAllByMemberId("member-1");
    callOrder.verify(authIdentityRepository).deleteAllByMemberId("member-1");
    callOrder.verify(refreshTokenRepository).deleteAllByMemberId("member-1");
    callOrder.verify(memberRepository).delete(member);
  }

  @Test
  @DisplayName("연관 일과가 없는 회원도 정상적으로 탈퇴된다")
  void withdraw_noRoutines_deletesMemberOnly() {
    Member member = new Member();
    member.setId("member-2");
    when(memberRepository.findById("member-2")).thenReturn(Optional.of(member));
    when(routineRepository.findAllByProfileMemberId("member-2")).thenReturn(List.of());

    memberService.withdraw("member-2");

    verify(routineRepository).deleteAll(List.of());
    // 세션 기록은 member를 외래키로 참조하지 않으므로 직접 지워야 남지 않는다.
    verify(refreshTokenRepository).deleteAllByMemberId("member-2");
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

  @Test
  @DisplayName("캐릭터를 설정하면 회원 정보에 반영된다")
  void updateCharacter_validRequest_updatesCharacter() {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setMember(member);
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));
    when(profileRepository.findFirstByMemberIdOrderByCreatedAtAsc("member-1"))
      .thenReturn(Optional.of(profile));

    MemberResponse response =
      memberService.updateCharacter("member-1", new MemberCharacterUpdateRequest(CharacterType.LULU));

    assertThat(response.character()).isEqualTo(CharacterType.LULU);
  }

  @Test
  @DisplayName("존재하지 않는 회원의 캐릭터를 설정하려 하면 MEMBER_NOT_FOUND를 던진다")
  void updateCharacter_missingMember_throwsMemberNotFound() {
    when(memberRepository.findById("missing")).thenReturn(Optional.empty());

    assertThatThrownBy(() ->
      memberService.updateCharacter("missing", new MemberCharacterUpdateRequest(CharacterType.POPO)))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_NOT_FOUND));
  }
}
