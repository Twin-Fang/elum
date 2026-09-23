package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class WithdrawnMemberServiceTest {

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

  @Mock
  private AiCallLogRepository aiCallLogRepository;

  @Mock
  private DeviceLinkRepository deviceLinkRepository;

  @Mock
  private SubscriptionRepository subscriptionRepository;

  @Mock
  private SubscriptionService subscriptionService;

  @Mock
  private SystemConfigService systemConfigService;

  @InjectMocks
  private WithdrawnMemberService withdrawnMemberService;

  private Member withdrawn(String id, LocalDateTime withdrawnAt) {
    Member member = new Member();
    member.setId(id);
    member.setUsername("kakao_" + id);
    member.setStatus(MemberStatus.WITHDRAWN);
    member.setWithdrawnAt(withdrawnAt);
    member.setTokenInvalidBefore(withdrawnAt);
    member.setTermsAgreed(true);
    member.setPrivacyAgreed(true);
    member.setOverseasTransferAgreed(true);
    member.setGuardianConfirmed(true);
    member.setMarketingAgreed(true);
    member.setConsentedAt(withdrawnAt.minusDays(30));
    member.setConsentVersion("2026-09-21");
    return member;
  }

  private void retentionDays(int days) {
    when(systemConfigService.getInt(ConfigKey.MEMBER_WITHDRAWN_RETENTION_DAYS)).thenReturn(days);
  }

  @Test
  @DisplayName("보관 기간은 관리자 설정값이고 기본은 365일이다")
  void retentionDays_comesFromConfigWithDefault365() {
    // 법 확인 뒤 바꿀 값이라 배포 없이 고칠 수 있어야 한다.
    assertThat(ConfigKey.MEMBER_WITHDRAWN_RETENTION_DAYS.getDefaultValue()).isEqualTo("365");
    retentionDays(30);

    assertThat(withdrawnMemberService.retentionDays()).isEqualTo(30);
  }

  @Test
  @DisplayName("S6 보관 만료 예정일은 탈퇴 시각에 보관 기간을 더한 날이다")
  void retentionExpiresAt_isWithdrawnAtPlusRetention() {
    LocalDateTime withdrawnAt = LocalDateTime.of(2026, 9, 23, 10, 0);
    retentionDays(365);

    assertThat(withdrawnMemberService.retentionExpiresAt(withdrawn("m1", withdrawnAt)))
      .isEqualTo(withdrawnAt.plusDays(365));
  }

  @Test
  @DisplayName("탈퇴하지 않은 계정에는 보관 만료 예정일이 없다")
  void retentionExpiresAt_activeMember_isNull() {
    Member active = new Member();
    active.setStatus(MemberStatus.ACTIVE);

    assertThat(withdrawnMemberService.retentionExpiresAt(active)).isNull();
  }

  @Test
  @DisplayName("S1 보관 기간 안이면 만료가 아니고, S2 지났으면 만료다")
  void isRetentionExpired_comparesWithRetention() {
    retentionDays(365);

    assertThat(withdrawnMemberService.isRetentionExpired(
      withdrawn("m1", LocalDateTime.now().minusDays(10)))).isFalse();
    assertThat(withdrawnMemberService.isRetentionExpired(
      withdrawn("m2", LocalDateTime.now().minusDays(400)))).isTrue();
  }

  @Test
  @DisplayName("탈퇴 시각이 비어 있는 탈퇴 계정은 만료로 본다 — 보관을 약속한 기간을 넘겨 남기지 않는다")
  void isRetentionExpired_missingWithdrawnAt_isExpired() {
    Member member = withdrawn("m1", LocalDateTime.now());
    member.setWithdrawnAt(null);

    assertThat(withdrawnMemberService.isRetentionExpired(member)).isTrue();
  }

  @Test
  @DisplayName("S1 되살리면 ACTIVE 로 돌아오고 탈퇴 시각을 지운다")
  void revive_restoresActive() {
    Member member = withdrawn("m1", LocalDateTime.now().minusDays(10));

    withdrawnMemberService.revive(member);

    assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
    assertThat(member.getWithdrawnAt()).isNull();
    // 새 계정을 만들지 않는다 — 같은 회원 ID 라야 AI 사용 기록과 한도가 이어진다.
    verify(memberRepository, never()).save(any(Member.class));
    assertThat(member.getId()).isEqualTo("m1");
  }

  @Test
  @DisplayName("S1 되살리면 약관 동의를 다시 받는다 — 동의 값을 비운다")
  void revive_clearsConsents() {
    Member member = withdrawn("m1", LocalDateTime.now().minusDays(10));

    withdrawnMemberService.revive(member);

    // 비워 두면 앱이 가입 때처럼 동의 화면을 띄운다.
    assertThat(member.hasRequiredConsents()).isFalse();
    assertThat(member.getMarketingAgreed()).isFalse();
    assertThat(member.getConsentedAt()).isNull();
    assertThat(member.getConsentVersion()).isNull();
  }

  @Test
  @DisplayName("S1 되살리면 이룸이·일과 없이 가입 때처럼 빈 프로필과 Free 구독을 만든다")
  void revive_createsEmptyProfileAndFreeSubscription() {
    Member member = withdrawn("m1", LocalDateTime.now().minusDays(10));

    withdrawnMemberService.revive(member);

    ArgumentCaptor<Profile> profile = ArgumentCaptor.forClass(Profile.class);
    verify(profileRepository).save(profile.capture());
    assertThat(profile.getValue().getMember()).isSameAs(member);
    // 이름이 비어 있어야 앱이 온보딩부터 다시 시작한다.
    assertThat(profile.getValue().getNickname()).isNull();
    assertThat(profile.getValue().getCharacter()).isEqualTo(CharacterType.LULU);
    verify(subscriptionService).createFreeIfAbsent(member);
    // 일과는 만들지 않는다 — 탈퇴 때 지운 것은 돌아오지 않는다.
    verifyNoInteractions(routineRepository);
  }

  @Test
  @DisplayName("S4 되살아나도 탈퇴 전에 발급된 토큰을 막는 기준은 그대로 둔다")
  void revive_keepsTokenInvalidBefore() {
    LocalDateTime withdrawnAt = LocalDateTime.now().minusDays(10);
    Member member = withdrawn("m1", withdrawnAt);

    withdrawnMemberService.revive(member);

    // 비우면 탈퇴 전에 흘러나간 액세스 토큰이 되살아난다.
    assertThat(member.getTokenInvalidBefore()).isEqualTo(withdrawnAt);
  }

  @Test
  @DisplayName("S8 되살릴 때 이룸이 휴대폰 연결을 되살리지 않는다 — 새 연결 암호로만 붙는다")
  void revive_doesNotRestoreDeviceLinks() {
    Member member = withdrawn("m1", LocalDateTime.now().minusDays(10));

    withdrawnMemberService.revive(member);

    verifyNoInteractions(deviceLinkRepository);
    verifyNoInteractions(refreshTokenRepository);
  }

  @Test
  @DisplayName("S2·S7·S9 완전 삭제는 남겨 둔 계정·소셜 신원을 지우고 AI 기록에서 회원을 뗀다")
  void purge_removesRetainedRowsAndDetachesAiLogs() {
    Member member = withdrawn("m1", LocalDateTime.now().minusDays(400));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    when(routineRepository.findAllByProfileMemberId("m1")).thenReturn(List.of());

    withdrawnMemberService.purge("m1");

    verify(authIdentityRepository).deleteAllByMemberId("m1");
    // AI 기록 행은 운영 지표라 남기고, 누가 썼는지만 뗀다 (#191).
    verify(aiCallLogRepository).detachMember("m1");
    verify(aiCallLogRepository, never()).deleteAll();
    // 탈퇴 때 지웠어야 할 것도 한 번 더 지운다 — 남아 있으면 계정 행이 외래키에 걸린다.
    verify(profileRepository).deleteAllByMemberId("m1");
    verify(subscriptionRepository).deleteByMemberId("m1");
    verify(refreshTokenRepository).deleteAllByMemberId("m1");
    verify(deviceLinkRepository).deleteAllByMemberId("m1");

    // 지우기를 바로 DB 에 보낸다. 같은 트랜잭션에서 같은 아이디로 새 계정을 만들 때(S2)
    // Hibernate 가 넣기를 먼저 보내 고유 제약에 걸리지 않게 한다.
    InOrder order = inOrder(memberRepository);
    order.verify(memberRepository).delete(member);
    order.verify(memberRepository).flush();
  }

  @Test
  @DisplayName("이미 지워진 계정의 완전 삭제는 할 일 없이 끝난다 — 스케줄러와 관리자 버튼이 겹쳐도 된다")
  void purge_missingMember_isNoop() {
    when(memberRepository.findById("gone")).thenReturn(Optional.empty());

    withdrawnMemberService.purge("gone");

    verify(memberRepository, never()).delete(any(Member.class));
    verifyNoInteractions(aiCallLogRepository, authIdentityRepository);
  }

  @Test
  @DisplayName("탈퇴 상태가 아닌 계정은 완전 삭제하지 않는다 — 사이에 되살아났을 수 있다")
  void purge_notWithdrawn_refuses() {
    Member member = withdrawn("m1", LocalDateTime.now().minusDays(400));
    member.setStatus(MemberStatus.ACTIVE);
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    assertThatThrownBy(() -> withdrawnMemberService.purge("m1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_NOT_WITHDRAWN));
    verify(memberRepository, never()).delete(any(Member.class));
    verifyNoInteractions(aiCallLogRepository, authIdentityRepository);
  }

  @Test
  @DisplayName("S2·S7 보관 기간이 지난 탈퇴 계정만 고른다 — 기준은 지금에서 보관 기간을 뺀 시각이다")
  void findExpiredIds_usesRetentionThreshold() {
    retentionDays(365);
    when(memberRepository.findWithdrawnIdsUntil(eq(MemberStatus.WITHDRAWN), any(LocalDateTime.class)))
      .thenReturn(List.of("m1", "m2"));

    List<String> ids = withdrawnMemberService.findExpiredIds();

    assertThat(ids).containsExactly("m1", "m2");
    ArgumentCaptor<LocalDateTime> threshold = ArgumentCaptor.forClass(LocalDateTime.class);
    verify(memberRepository).findWithdrawnIdsUntil(eq(MemberStatus.WITHDRAWN), threshold.capture());
    assertThat(threshold.getValue())
      .isCloseTo(LocalDateTime.now().minusDays(365), within(5, ChronoUnit.SECONDS));
  }
}
