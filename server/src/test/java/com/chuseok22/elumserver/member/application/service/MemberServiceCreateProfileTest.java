package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.transaction.annotation.Transactional;

/**
 * 마지막 이룸이에서 나간 보호자가 새 이룸이를 만든다 (#361·#362).
 *
 * <p>이룸이는 가입 때(createOwnProfile)만 생겼다. 나간 뒤 이름을 저장하면 404 PROFILE_NOT_FOUND 로 막혔다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MemberServiceCreateProfileTest {

  @Mock private MemberRepository memberRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private GuardianshipService guardianshipService;
  @Mock private EntitlementService entitlementService;
  // 쓰지 않는 의존성 — InjectMocks 가 생성자를 채우게 목으로 둔다.
  @Mock private com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository authIdentityRepository;
  @Mock private com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository refreshTokenRepository;
  @Mock private com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository deviceLinkRepository;
  @Mock private com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository subscriptionRepository;
  @Mock private com.chuseok22.elumserver.adreward.infrastructure.repository.AdRewardSessionRepository adRewardSessionRepository;
  @Mock private com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository aiCallLogRepository;

  @InjectMocks private MemberService memberService;

  private final Caller guardian = Caller.guardian("member-1");

  private static Member member(MemberStatus status) {
    Member m = new Member();
    m.setId("member-1");
    m.setUsername("kakao_1");
    m.setStatus(status);
    return m;
  }

  private static Profile profile(String id) {
    Profile p = new Profile();
    p.setId(id);
    return p;
  }

  @Test
  @DisplayName("연결된 이룸이가 없으면 새 이룸이를 하나 만들고 그 이룸이를 담아 응답한다")
  void createsWhenNoProfile() {
    Member m = member(MemberStatus.ACTIVE);
    Profile created = profile("p-new");
    when(memberRepository.findByIdForUpdate("member-1")).thenReturn(Optional.of(m));
    when(profileAccessGuard.profilesOf(guardian)).thenReturn(List.of());
    when(guardianshipService.createOwnProfile(m)).thenReturn(created);

    MemberResponse response = memberService.createProfile(guardian);

    verify(guardianshipService).createOwnProfile(m);
    assertThat(response.profiles()).extracting("id").containsExactly("p-new");
  }

  @Test
  @DisplayName("이미 이룸이가 있으면 만들지 않고 지금 상태를 그대로 돌려준다 — 재시도·동시 호출이 이룸이를 둘로 만들지 않는다")
  void isIdempotentWhenProfileExists() {
    Member m = member(MemberStatus.ACTIVE);
    when(memberRepository.findByIdForUpdate("member-1")).thenReturn(Optional.of(m));
    when(profileAccessGuard.profilesOf(guardian)).thenReturn(List.of(profile("p-1")));

    MemberResponse response = memberService.createProfile(guardian);

    verify(guardianshipService, never()).createOwnProfile(any());
    assertThat(response.profiles()).extracting("id").containsExactly("p-1");
  }

  @Test
  @DisplayName("계정 행을 먼저 잠근 뒤 이룸이 유무를 센다 — 잠금 전에 세면 동시 호출 둘이 모두 0 으로 보고 이룸이를 둘 만든다")
  void locksMemberBeforeCounting() {
    Member m = member(MemberStatus.ACTIVE);
    when(memberRepository.findByIdForUpdate("member-1")).thenReturn(Optional.of(m));
    when(profileAccessGuard.profilesOf(guardian)).thenReturn(List.of());
    when(guardianshipService.createOwnProfile(m)).thenReturn(profile("p-new"));

    memberService.createProfile(guardian);

    InOrder order = inOrder(memberRepository, profileAccessGuard, guardianshipService);
    order.verify(memberRepository).findByIdForUpdate("member-1");
    order.verify(profileAccessGuard).profilesOf(guardian);
    order.verify(guardianshipService).createOwnProfile(m);
  }

  @Test
  @DisplayName("이룸이 휴대폰 토큰은 403 — 이룸이를 만들지 않고 계정도 건드리지 않는다")
  void elumiIsForbidden() {
    Caller elumi = Caller.elumi("member-1", "link-1");

    assertThatThrownBy(() -> memberService.createProfile(elumi))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI));
    verifyNoInteractions(memberRepository, guardianshipService);
  }

  @Test
  @DisplayName("탈퇴한 계정은 MEMBER_NOT_FOUND — 이룸이를 만들지 않는다")
  void withdrawnMemberCannotCreate() {
    when(memberRepository.findByIdForUpdate("member-1")).thenReturn(Optional.of(member(MemberStatus.WITHDRAWN)));

    assertThatThrownBy(() -> memberService.createProfile(guardian))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.MEMBER_NOT_FOUND));
    verify(guardianshipService, never()).createOwnProfile(any());
  }

  @Test
  @DisplayName("쓰기 트랜잭션이다 — 클래스의 읽기 전용에 기대면 이룸이 저장이 조용히 버려진다")
  void isWriteTransaction() throws Exception {
    Transactional tx = MemberService.class.getMethod("createProfile", Caller.class).getAnnotation(Transactional.class);

    assertThat(tx).isNotNull();
    assertThat(tx.readOnly()).isFalse();
  }
}
