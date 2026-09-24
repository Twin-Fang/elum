package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.auth.infrastructure.entity.AuthIdentity;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.application.dto.request.MemberCharacterUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.annotation.Transactional;

@ExtendWith(MockitoExtension.class)
class MemberServiceTest {

  @Mock
  private MemberRepository memberRepository;

  @Mock
  private ProfileRepository profileRepository;

  @Mock
  private GuardianshipService guardianshipService;

  @Mock
  private AuthIdentityRepository authIdentityRepository;

  @Mock
  private RefreshTokenRepository refreshTokenRepository;

  @Mock
  private AiCallLogRepository aiCallLogRepository;

  @Mock
  private DeviceLinkRepository deviceLinkRepository;

  @Mock
  private SubscriptionRepository subscriptionRepository;

  @Mock
  private EntitlementService entitlementService;

  @InjectMocks
  private MemberService memberService;

  private Member activeMember(String id) {
    Member member = new Member();
    member.setId(id);
    member.setUsername("kakao_" + id);
    member.setStatus(MemberStatus.ACTIVE);
    member.setLastLoginAt(LocalDateTime.now().minusHours(1));
    member.setLastActivityAt(LocalDateTime.now().minusMinutes(5));
    member.setLoginCount(12);
    member.setPassword("{bcrypt}hash");
    member.setTermsAgreed(true);
    member.setConsentedAt(LocalDateTime.now().minusDays(30));
    member.setConsentVersion("2026-09-24");
    return member;
  }

  private AuthIdentity kakaoIdentity(String memberId) {
    AuthIdentity identity = new AuthIdentity();
    identity.setMemberId(memberId);
    identity.setProvider(OAuthProvider.KAKAO);
    identity.setProviderUserId("kakao-9999");
    identity.setEmail("parent@kakao.com");
    identity.setEmailVerified(true);
    return identity;
  }

  @Test
  @DisplayName("탈퇴하면 계정 행을 지우지 않고 WITHDRAWN 과 탈퇴 시각을 남긴다 (#372)")
  void withdraw_keepsMemberRowAsWithdrawn() {
    Member member = activeMember("member-1");
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));

    LocalDateTime before = LocalDateTime.now();
    memberService.withdraw("member-1");

    assertThat(member.getStatus()).isEqualTo(MemberStatus.WITHDRAWN);
    assertThat(member.getWithdrawnAt()).isAfterOrEqualTo(before);
    // 재가입을 알아볼 기준이라 행은 남긴다. 지우면 같은 소셜 계정이 새 계정으로 들어온다.
    verify(memberRepository, never()).delete(any(Member.class));
    // 동의 기록(값·시각·버전)은 남긴다 — 무엇에 동의했었는지의 증빙이다. 되살릴 때 비운다. 방침 4조 보관 항목.
    assertThat(member.getTermsAgreed()).isTrue();
    assertThat(member.getConsentedAt()).isNotNull();
    assertThat(member.getConsentVersion()).isEqualTo("2026-09-24");
    // 아이디 로그인 비밀번호 변환값은 남긴다 — 1년 안에 같은 아이디로 오면 확인해 되살려야 한다. 방침 4조 보관 항목.
    assertThat(member.getPassword()).isEqualTo("{bcrypt}hash");
    // 재가입 판별에 필요 없는 활동 기록은 비운다 (최소 보관). 방침 4조가 보관 항목으로 적지 않은 값이다.
    assertThat(member.getLastLoginAt()).isNull();
    assertThat(member.getLastActivityAt()).isNull();
    assertThat(member.getLoginCount()).isZero();
  }

  @Test
  @DisplayName("탈퇴하면 연결된 이룸이마다 나가기를 하고 세션·이룸이 휴대폰 연결·구독은 즉시 지운다 (최소 보관 · 다중 보호자 4-3)")
  void withdraw_deletesEverythingNotNeededForRejoin() {
    Member member = activeMember("member-1");
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));

    memberService.withdraw("member-1");

    // 이룸이·일과는 나가기 규칙이 정리한다 — 내가 만든 일과, 내가 붙인 휴대폰, 관계. 혼자 돌보던 이룸이는
    // 지우고 함께 돌보는 이룸이는 남은 보호자에게 남긴다. 계정의 "모든 프로필"을 지우지 않는다.
    verify(guardianshipService).leaveAll("member-1");
    verify(profileRepository, never()).deleteAllByMemberId(any());
    verify(refreshTokenRepository).deleteAllByMemberId("member-1");
    verify(deviceLinkRepository).deleteAllByMemberId("member-1");
    verify(subscriptionRepository).deleteByMemberId("member-1");
  }

  @Test
  @DisplayName("S1 탈퇴해도 AI 호출 기록의 회원 식별자를 떼지 않는다 — 재가입하면 한도가 이어진다")
  void withdraw_keepsAiCallLogOwner() {
    Member member = activeMember("member-3");
    when(memberRepository.findById("member-3")).thenReturn(Optional.of(member));

    memberService.withdraw("member-3");

    // 떼는 순간 하루·주간 한도가 세는 기록이 누구 것도 아니게 되어, 재가입한 계정의 사용량이 0 이 된다.
    verify(aiCallLogRepository, never()).detachMember(any());
    verify(aiCallLogRepository, never()).deleteAll();
  }

  @Test
  @DisplayName("S3 탈퇴하면 소셜 신원은 남기되 이메일을 비운다 — 다른 제공자로 새로 가입할 때 충돌로 막히지 않는다")
  void withdraw_keepsIdentityButClearsEmail() {
    Member member = activeMember("member-5");
    AuthIdentity identity = kakaoIdentity("member-5");
    when(memberRepository.findById("member-5")).thenReturn(Optional.of(member));
    when(authIdentityRepository.findAllByMemberId("member-5")).thenReturn(List.of(identity));

    memberService.withdraw("member-5");

    // 제공자 + 제공자 회원번호는 남아야 같은 소셜 계정이 다시 왔을 때 알아본다.
    verify(authIdentityRepository, never()).deleteAllByMemberId(any());
    assertThat(identity.getProvider()).isEqualTo(OAuthProvider.KAKAO);
    assertThat(identity.getProviderUserId()).isEqualTo("kakao-9999");
    // 이메일은 재가입 판별에 쓰지 않는다. 남겨 두면 네이버로 같은 이메일 가입이 이메일 충돌로 막힌다.
    assertThat(identity.getEmail()).isNull();
    assertThat(identity.isEmailVerified()).isFalse();
  }

  @Test
  @DisplayName("S4 탈퇴하면 그 전에 발급된 액세스 토큰을 막고 세션을 지운다")
  void withdraw_invalidatesIssuedTokens() {
    Member member = activeMember("member-6");
    when(memberRepository.findById("member-6")).thenReturn(Optional.of(member));

    LocalDateTime before = LocalDateTime.now();
    memberService.withdraw("member-6");

    // 리프레시만 지우면 받아 둔 액세스 토큰으로 만료(하루)까지 계속 들어온다.
    assertThat(member.getTokenInvalidBefore()).isAfterOrEqualTo(before);
    verify(refreshTokenRepository).deleteAllByMemberId("member-6");
  }

  @Test
  @DisplayName("S5 탈퇴 도중 실패하면 예외를 그대로 올리고 계정 상태를 바꾸지 않는다")
  void withdraw_failureMidway_propagatesAndLeavesStatus() {
    Member member = activeMember("member-7");
    when(memberRepository.findById("member-7")).thenReturn(Optional.of(member));
    doThrow(new IllegalStateException("구독 삭제 실패"))
      .when(subscriptionRepository).deleteByMemberId("member-7");

    // 예외를 삼키면 트랜잭션이 커밋돼 반쯤 지워진 계정이 남는다. 올라가야 전부 롤백되고
    // 앱이 에러 코드와 함께 머문다 (#187).
    assertThatThrownBy(() -> memberService.withdraw("member-7"))
      .isInstanceOf(IllegalStateException.class);
    assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
    assertThat(member.getWithdrawnAt()).isNull();
  }

  @Test
  @DisplayName("E20 나가기 도중 실패하면 예외를 그대로 올리고 계정 상태·소셜 신원을 건드리지 않는다 — 트랜잭션이 전부 되돌린다")
  void e20_withdraw_leaveFails_keepsAccount() {
    Member member = activeMember("member-9");
    when(memberRepository.findById("member-9")).thenReturn(Optional.of(member));
    doThrow(new IllegalStateException("DB 끊김")).when(guardianshipService).leaveAll("member-9");

    assertThatThrownBy(() -> memberService.withdraw("member-9")).isInstanceOf(IllegalStateException.class);

    assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
    verify(authIdentityRepository, never()).findAllByMemberId(any());
    verify(subscriptionRepository, never()).deleteByMemberId(any());
  }

  @Test
  @DisplayName("E19 나가기가 먼저고 상태 변경이 마지막이다 — 이룸이 정리가 실패하면 WITHDRAWN 이 남지 않는다")
  void e19_withdraw_leavesProfilesBeforeMarkingWithdrawn() {
    Member member = activeMember("member-10");
    when(memberRepository.findById("member-10")).thenReturn(Optional.of(member));
    doAnswer(invocation -> {
      // 나가는 동안 계정은 아직 살아 있다 — 대표 보호자 넘기기가 이 계정을 지워질 사람으로 보지 않는다.
      assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
      return null;
    }).when(guardianshipService).leaveAll("member-10");

    memberService.withdraw("member-10");

    InOrder order = inOrder(guardianshipService, refreshTokenRepository, subscriptionRepository);
    order.verify(guardianshipService).leaveAll("member-10");
    order.verify(refreshTokenRepository).deleteAllByMemberId("member-10");
    order.verify(subscriptionRepository).deleteByMemberId("member-10");
    assertThat(member.getStatus()).isEqualTo(MemberStatus.WITHDRAWN);
  }

  @Test
  @DisplayName("S5 탈퇴는 쓰기 트랜잭션 하나로 묶여 있어 도중에 실패하면 전부 되돌린다")
  void withdraw_runsInOneWriteTransaction() throws NoSuchMethodException {
    Transactional transactional = MemberService.class.getMethod("withdraw", String.class)
      .getAnnotation(Transactional.class);

    // 클래스 기본값이 읽기 전용이다. 메서드에 따로 없으면 지우기가 flush 되지 않는다.
    assertThat(transactional).isNotNull();
    assertThat(transactional.readOnly()).isFalse();
  }

  @Test
  @DisplayName("S8 탈퇴하면 이룸이 휴대폰 연결을 지운다 — 되살아나도 새 연결 암호가 있어야 붙는다")
  void withdraw_deletesDeviceLinks() {
    Member member = activeMember("member-4");
    when(memberRepository.findById("member-4")).thenReturn(Optional.of(member));

    memberService.withdraw("member-4");

    // device_link 는 member를 외래키로 참조하지 않는다. 여기서 안 지우면 남는다.
    verify(deviceLinkRepository).deleteAllByMemberId("member-4");
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
  @DisplayName("이미 탈퇴한 계정은 없는 회원으로 본다 — 다시 탈퇴하거나 정보를 볼 수 없다")
  void withdrawnMember_isTreatedAsNotFound() {
    Member member = activeMember("member-8");
    member.setStatus(MemberStatus.WITHDRAWN);
    when(memberRepository.findById("member-8")).thenReturn(Optional.of(member));

    assertThatThrownBy(() -> memberService.withdraw("member-8"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_NOT_FOUND));
    assertThatThrownBy(() -> memberService.getConsents("member-8"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_NOT_FOUND));
    verify(guardianshipService, never()).leaveAll(any());
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
