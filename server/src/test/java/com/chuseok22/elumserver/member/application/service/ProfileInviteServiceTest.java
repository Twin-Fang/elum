package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.link.core.CodeDigest;
import com.chuseok22.elumserver.link.core.LinkCode;
import com.chuseok22.elumserver.member.application.dto.response.ProfileInviteResponse;
import com.chuseok22.elumserver.member.application.dto.response.ProfileJoinResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileInviteRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.lang.reflect.Method;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
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
 * 초대 코드 발급·입력 (이슈 #361, 명세 4-6 · 7-1 E1~E10·E16).
 *
 * <p>초대 코드는 이룸이의 일과를 여는 자격증명이다. <b>실패 경로를 정상 경로만큼 고정한다</b> — 만료·재사용·
 * 본인 코드·시도 초과가 조용히 통하면 남의 가정 이룸이의 일과가 그대로 보인다. 테스트 이름에 엣지 케이스 번호를 단다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ProfileInviteServiceTest {

  private static final String CODE = "A7K3M9";

  @Mock private ProfileRepository profileRepository;
  @Mock private ProfileGuardianRepository profileGuardianRepository;
  @Mock private ProfileInviteRepository profileInviteRepository;
  @Mock private MemberRepository memberRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private GuardianshipService guardianshipService;
  @Mock private ProfileInviteRateLimiter rateLimiter;

  @InjectMocks private ProfileInviteService service;

  private Profile profile;
  private Member joiner;
  private ProfileInvite invite;

  @BeforeEach
  void setUp() {
    profile = new Profile();
    profile.setId("p1");
    profile.setNickname("하늘이");
    profile.setCharacter(CharacterType.LULU);

    joiner = new Member();
    joiner.setId("J");
    joiner.setUsername("naver_1");
    joiner.setStatus(MemberStatus.ACTIVE);
    joiner.setTermsAgreed(true);
    joiner.setPrivacyAgreed(true);
    joiner.setOverseasTransferAgreed(true);
    joiner.setGuardianConfirmed(true);
    when(memberRepository.findById("J")).thenReturn(Optional.of(joiner));

    when(rateLimiter.tryIssue(anyString())).thenReturn(true);
    when(rateLimiter.tryRedeem(anyString())).thenReturn(true);

    invite = openInvite("i1", "I");
    stubInvitesFor(CODE, invite);
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.of(profile));
    // 코드를 낸 사람(I)은 지금도 이 이룸이를 돌본다. 넣는 사람(J)은 아직 아니다.
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "I")).thenReturn(true);
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "J")).thenReturn(false);
    when(guardianshipService.removeEmptyOwnProfiles(anyString(), anyString())).thenReturn(List.of());
  }

  private ProfileInvite openInvite(String id, String issuedBy) {
    ProfileInvite i = new ProfileInvite();
    i.setId(id);
    i.setProfileId("p1");
    i.setIssuedBy(issuedBy);
    i.setCodeHash(CodeDigest.sha256(CODE));
    i.setExpiresAt(LocalDateTime.now().plusMinutes(5));
    return i;
  }

  private void stubInvitesFor(String code, ProfileInvite... rows) {
    String hash = CodeDigest.sha256(code);
    when(profileInviteRepository.findProfileIdsByCodeHash(hash)).thenReturn(List.of("p1"));
    when(profileInviteRepository.findAllByCodeHashAndProfileIdForUpdate(hash, "p1")).thenReturn(List.of(rows));
  }

  private static void assertFails(Runnable call, ErrorCode expected) {
    assertThatThrownBy(call::run)
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", expected);
  }

  // ───────────────────────── 발급 ─────────────────────────

  @Test
  @DisplayName("발급하면 우리가 만들 수 있는 모양의 코드와 10분 만료가 나오고, 해시만 저장한다")
  void issue_createsCodeAndStoresOnlyTheHash() {
    ProfileInviteResponse res = service.issue(Caller.guardian("I"), "p1");

    assertThat(LinkCode.hasValidShape(res.code())).isTrue();
    assertThat(res.expiresInSeconds()).isEqualTo(600);
    assertThat(res.expiresAt()).isAfter(LocalDateTime.now().plusMinutes(9));
    verify(profileInviteRepository).save(argThat(saved ->
      saved.getProfileId().equals("p1")
        && saved.getIssuedBy().equals("I")
        && saved.getCodeHash().equals(CodeDigest.sha256(res.code()))
        // 원문이 어디에도 남지 않는다
        && !saved.getCodeHash().contains(res.code())));
  }

  @Test
  @DisplayName("E9 다시 발급하면 내가 이 이룸이에 낸 이전 미사용 코드는 폐기된다 — 화면에 보이는 코드만 통해야 한다")
  void e9_issue_revokesMyPreviousOpenInvites() {
    ProfileInvite previous = openInvite("old", "I");
    when(profileInviteRepository.findAllByProfileIdAndIssuedByAndRedeemedAtIsNullAndRevokedAtIsNull("p1", "I"))
      .thenReturn(List.of(previous));

    service.issue(Caller.guardian("I"), "p1");

    assertThat(previous.getRevokedAt()).isNotNull();
  }

  @Test
  @DisplayName("E7 이룸이 휴대폰 토큰으로는 발급할 수 없다 — 이룸이 토큰의 memberId 는 그 휴대폰을 붙여 준 보호자다")
  void e7_issue_elumiCallerIsForbidden() {
    assertFails(() -> service.issue(Caller.elumi("I", "link1"), "p1"), ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    verifyNoInteractions(profileInviteRepository);
  }

  @Test
  @DisplayName("연결되지 않은 이룸이에는 발급할 수 없다 (403) — 아무것도 저장하지 않는다")
  void issue_notGuardianOfProfile_isForbidden() {
    doThrow(new CustomException(ErrorCode.PROFILE_ACCESS_DENIED))
      .when(profileAccessGuard).requireGuardianOf("X", "p1");

    assertFails(() -> service.issue(Caller.guardian("X"), "p1"), ErrorCode.PROFILE_ACCESS_DENIED);
    verify(profileInviteRepository, never()).save(any());
  }

  @Test
  @DisplayName("없는 이룸이도 남의 이룸이와 같은 403 이다 — 존재 여부를 흘리지 않는다")
  void issue_unknownProfile_isTheSame403() {
    when(profileRepository.findByIdForUpdate("ghost")).thenReturn(Optional.empty());

    assertFails(() -> service.issue(Caller.guardian("I"), "ghost"), ErrorCode.PROFILE_ACCESS_DENIED);
  }

  @Test
  @DisplayName("발급은 이룸이 행을 잠근 뒤 연결을 본다 — 그사이 내가 나갔다면(나가기도 같은 잠금) 코드를 낼 수 없다")
  void issue_locksProfileBeforeCheckingMembership() {
    service.issue(Caller.guardian("I"), "p1");

    InOrder order = inOrder(profileRepository, profileAccessGuard);
    order.verify(profileRepository).findByIdForUpdate("p1");
    order.verify(profileAccessGuard).requireGuardianOf("I", "p1");
  }

  @Test
  @DisplayName("E10 발급이 너무 잦으면 429 — 행을 불리지 못하게 한다")
  void e10_issue_rateLimited() {
    when(rateLimiter.tryIssue("I")).thenReturn(false);

    assertFails(() -> service.issue(Caller.guardian("I"), "p1"), ErrorCode.PROFILE_INVITE_TOO_MANY_ATTEMPTS);
    verify(profileInviteRepository, never()).save(any());
  }

  @Test
  @DisplayName("살아 있는 다른 코드와 겹치면 다시 뽑는다 — 같은 해시가 둘이면 어느 이룸이인지 가릴 수 없다")
  void issue_redrawsWhenCodeCollidesWithLiveOne() {
    when(profileInviteRepository.existsByCodeHashAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfter(
      anyString(), any(LocalDateTime.class))).thenReturn(true, false);

    ProfileInviteResponse res = service.issue(Caller.guardian("I"), "p1");

    assertThat(res.code()).isNotBlank();
    verify(profileInviteRepository, org.mockito.Mockito.times(2))
      .existsByCodeHashAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfter(anyString(), any(LocalDateTime.class));
  }

  // ───────────────────────── 입력 · 합류 ─────────────────────────

  @Test
  @DisplayName("코드를 넣으면 kind=GUARDIAN 으로 붙고 코드는 쓴 것으로 남는다 (E16 다시 초대받아 들어오는 것도 같은 길이다)")
  void redeem_joinsAsGuardianAndConsumesTheCode() {
    ProfileJoinResponse res = service.redeem(Caller.guardian("J"), CODE, " 아빠 ");

    verify(profileGuardianRepository).save(argThat((ProfileGuardian g) ->
      g.getProfile() == profile
        && g.getMember() == joiner
        && g.getKind() == GuardianKind.GUARDIAN
        && "아빠".equals(g.getDisplayName())
        && g.getJoinedAt() != null));
    assertThat(invite.getRedeemedBy()).isEqualTo("J");
    assertThat(invite.getRedeemedAt()).isNotNull();
    assertThat(res.profile().id()).isEqualTo("p1");
    assertThat(res.profile().nickname()).isEqualTo("하늘이");
    assertThat(res.removedProfileIds()).isEmpty();
  }

  @Test
  @DisplayName("소문자·공백·하이픈이 섞여도 맞춰서 받는다")
  void redeem_normalizesInput() {
    service.redeem(Caller.guardian("J"), "a7k-3m9", null);

    assertThat(invite.getRedeemedAt()).isNotNull();
  }

  @Test
  @DisplayName("E1 코드를 만든 사람이 자기 코드를 넣으면 409 — 코드는 쓰이지 않고 남는다")
  void e1_redeem_ownCode_conflict() {
    invite.setIssuedBy("I");
    when(memberRepository.findById("I")).thenReturn(Optional.of(joiner));
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "I")).thenReturn(true);

    assertFails(() -> service.redeem(Caller.guardian("I"), CODE, null), ErrorCode.PROFILE_ALREADY_GUARDIAN);
    assertThat(invite.getRedeemedAt()).isNull();
    assertThat(invite.getRevokedAt()).isNull();
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E2 이미 함께하는 사람이 넣으면 409 — 코드는 다른 사람을 위해 남는다")
  void e2_redeem_alreadyGuardian_conflict() {
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "J")).thenReturn(true);

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_ALREADY_GUARDIAN);
    assertThat(invite.getRedeemedAt()).isNull();
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E3 이룸이 행을 먼저 잠그고 그 뒤에 코드 행을 새로 읽는다 — 같은 코드를 동시에 넣어도 한 명만 합류한다")
  void e3_redeem_locksProfileThenReadsInviteRows() {
    service.redeem(Caller.guardian("J"), CODE, null);

    InOrder order = inOrder(profileInviteRepository, profileRepository);
    // 잠그기 전에는 값(id)만 읽는다 — 행을 읽어 두면 영속성 컨텍스트에 옛 상태가 남아 잠근 뒤에도 옛 상태가 보인다
    order.verify(profileInviteRepository).findProfileIdsByCodeHash(CodeDigest.sha256(CODE));
    order.verify(profileRepository).findByIdForUpdate("p1");
    order.verify(profileInviteRepository).findAllByCodeHashAndProfileIdForUpdate(CodeDigest.sha256(CODE), "p1");
  }

  @Test
  @DisplayName("E3 앞사람이 이미 쓴 코드를 뒤사람이 넣으면 '맞지 않아요' — 합류하지 않고 시도 횟수를 센다")
  void e3_redeem_codeAlreadyUsedByEarlierRequest() {
    invite.setRedeemedBy("K");
    invite.setRedeemedAt(LocalDateTime.now().minusSeconds(1));

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_NOT_FOUND);
    assertThat(invite.getFailedAttempts()).isEqualTo(1);
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E4 코드를 낸 사람이 나갔다면 폐기돼 있다 — 입력하면 '맞지 않아요'")
  void e4_redeem_revokedByIssuerLeaving() {
    invite.setRevokedAt(LocalDateTime.now().minusMinutes(1));

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_NOT_FOUND);
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E4 폐기가 어긋나 있어도 낸 사람이 더 이상 이룸이를 돌보지 않으면 합류시키지 않고 코드를 폐기한다")
  void e4_redeem_issuerNoLongerGuardian() {
    when(profileGuardianRepository.existsByProfileIdAndMemberId("p1", "I")).thenReturn(false);

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_NOT_FOUND);
    assertThat(invite.getRevokedAt()).isNotNull();
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E5 입력하는 사이에 이룸이가 지워졌으면(마지막 보호자가 나감) 합류하지 않는다")
  void e5_redeem_profileDeletedMeanwhile() {
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.empty());

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_NOT_FOUND);
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E5 코드 행이 이룸이와 함께 사라졌어도(CASCADE) 같은 응답이다")
  void e5_redeem_inviteRowsGoneAfterLock() {
    when(profileInviteRepository.findAllByCodeHashAndProfileIdForUpdate(CodeDigest.sha256(CODE), "p1"))
      .thenReturn(List.of());

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_NOT_FOUND);
  }

  @Test
  @DisplayName("E6 약관 동의 전에는 합류할 수 없다 — 동의 없이는 이룸이 정보를 볼 근거가 없다")
  void e6_redeem_requiresConsentFirst() {
    joiner.setGuardianConfirmed(false);

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.CONSENT_REQUIRED);
    verify(profileGuardianRepository, never()).save(any());
    assertThat(invite.getRedeemedAt()).isNull();
  }

  @Test
  @DisplayName("E6 온보딩을 안 한 새 가입자도 합류하고, 가입 때 생긴 빈 이룸이는 정리 대상으로 넘긴다")
  void e6_redeem_cleansUpEmptyOwnProfile() {
    when(guardianshipService.removeEmptyOwnProfiles("J", "p1")).thenReturn(List.of("empty1"));

    ProfileJoinResponse res = service.redeem(Caller.guardian("J"), CODE, null);

    assertThat(res.removedProfileIds()).containsExactly("empty1");
    // 합류를 쓴 뒤에 정리한다 — 합류한 이룸이는 건드리지 않게 id 를 넘긴다
    InOrder order = inOrder(profileGuardianRepository, guardianshipService);
    order.verify(profileGuardianRepository).save(any(ProfileGuardian.class));
    order.verify(guardianshipService).removeEmptyOwnProfiles("J", "p1");
  }

  @Test
  @DisplayName("E7 이룸이 휴대폰 토큰으로는 코드를 넣을 수 없다 — 아무것도 조회하지 않는다")
  void e7_redeem_elumiCallerIsForbidden() {
    assertFails(() -> service.redeem(Caller.elumi("J", "link1"), CODE, null),
      ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    verifyNoInteractions(profileInviteRepository);
    verify(rateLimiter, never()).tryRedeem(anyString());
  }

  @Test
  @DisplayName("E8 만료된 코드는 410")
  void e8_redeem_expired() {
    invite.setExpiresAt(LocalDateTime.now().minusSeconds(1));

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_EXPIRED);
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E8 없는 코드는 404 — 저장소에 없으면 합류하지 않는다")
  void e8_redeem_unknownCode() {
    when(profileInviteRepository.findProfileIdsByCodeHash(CodeDigest.sha256("ZZZZZZ"))).thenReturn(List.of());

    assertFails(() -> service.redeem(Caller.guardian("J"), "ZZZZZZ", null), ErrorCode.PROFILE_INVITE_NOT_FOUND);
  }

  @Test
  @DisplayName("E8 모양부터 틀린 입력(길이·헷갈리는 글자)은 저장소를 뒤지지 않고 404")
  void e8_redeem_malformedCodeNeverTouchesRepository() {
    for (String bad : new String[]{"", "A7K3M", "A7K3M9X", "A7K3O0", null}) {
      assertFails(() -> service.redeem(Caller.guardian("J"), bad, null), ErrorCode.PROFILE_INVITE_NOT_FOUND);
    }
    verifyNoInteractions(profileInviteRepository);
  }

  @Test
  @DisplayName("E8 이미 쓴 코드를 다섯 번 두드리면 그 코드는 막힌다 — 다섯 번째에 폐기, 이후는 429")
  void e8_redeem_fifthWrongTryRevokesTheCode() {
    invite.setRedeemedBy("K");
    invite.setRedeemedAt(LocalDateTime.now().minusMinutes(1));

    for (int i = 0; i < CodeDigest.MAX_FAILED_ATTEMPTS; i++) {
      assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_NOT_FOUND);
    }
    assertThat(invite.getFailedAttempts()).isEqualTo(CodeDigest.MAX_FAILED_ATTEMPTS);
    assertThat(invite.getRevokedAt()).isNotNull();

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_TOO_MANY_ATTEMPTS);
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E8 실패 횟수가 이미 한도면 쓸 수 있는 모양이어도 429 — 횟수를 지우고 되살릴 수 없다")
  void e8_redeem_failedAttemptsAtLimit() {
    invite.setFailedAttempts(CodeDigest.MAX_FAILED_ATTEMPTS);

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_TOO_MANY_ATTEMPTS);
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E8 실패 횟수는 실패 응답과 함께 저장돼야 한다 — 입력은 CustomException 에도 롤백하지 않는다")
  void e8_redeem_doesNotRollBackOnCustomException() throws NoSuchMethodException {
    Method redeem = ProfileInviteService.class.getMethod("redeem", Caller.class, String.class, String.class);

    Transactional tx = redeem.getAnnotation(Transactional.class);

    assertThat(tx).isNotNull();
    assertThat(tx.readOnly()).isFalse();
    // 기본 롤백이면 "다섯 번 틀리면 폐기"의 횟수가 응답과 함께 사라져 한도가 영원히 차지 않는다
    assertThat(tx.noRollbackFor()).contains(CustomException.class);
  }

  @Test
  @DisplayName("E10 계정당 시도 한도를 넘으면 429 — 코드를 조회하기도 전에 막는다")
  void e10_redeem_accountRateLimited() {
    when(rateLimiter.tryRedeem("J")).thenReturn(false);

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.PROFILE_INVITE_TOO_MANY_ATTEMPTS);
    verifyNoInteractions(profileInviteRepository);
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("E10 한도는 코드가 맞든 틀리든 센다 — 없는 코드를 무작위로 찍어도 흔적 없이 계속할 수 없다")
  void e10_redeem_countsEveryAttemptEvenWrongOnes() {
    when(profileInviteRepository.findProfileIdsByCodeHash(CodeDigest.sha256("ZZZZZZ"))).thenReturn(List.of());

    assertFails(() -> service.redeem(Caller.guardian("J"), "ZZZZZZ", null), ErrorCode.PROFILE_INVITE_NOT_FOUND);

    verify(rateLimiter).tryRedeem("J");
  }

  @Test
  @DisplayName("이름이 20자를 넘으면 400 — 시도 한도를 쓰기 전에 거른다")
  void redeem_displayNameTooLong_rejectedBeforeSpendingAnAttempt() {
    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, "가".repeat(21)), ErrorCode.INVALID_INPUT_VALUE);
    verify(rateLimiter, never()).tryRedeem(anyString());
    assertThat(invite.getRedeemedAt()).isNull();
  }

  @Test
  @DisplayName("탈퇴한 계정은 합류할 수 없다")
  void redeem_withdrawnMember_isRejected() {
    joiner.setStatus(MemberStatus.WITHDRAWN);

    assertFails(() -> service.redeem(Caller.guardian("J"), CODE, null), ErrorCode.MEMBER_NOT_FOUND);
    verify(profileGuardianRepository, never()).save(any());
  }

  @Test
  @DisplayName("같은 해시가 여러 줄이면 아직 쓸 수 있는 것을 쓴다 — 쓰이거나 폐기된 옛 줄이 앞서도 막히지 않는다")
  void redeem_prefersTheOpenRowAmongSameHash() {
    ProfileInvite usedOld = openInvite("old", "I");
    usedOld.setRedeemedAt(LocalDateTime.now().minusDays(1));
    List<ProfileInvite> rows = new ArrayList<>(List.of(usedOld, invite));
    when(profileInviteRepository.findAllByCodeHashAndProfileIdForUpdate(CodeDigest.sha256(CODE), "p1"))
      .thenReturn(rows);

    service.redeem(Caller.guardian("J"), CODE, null);

    assertThat(invite.getRedeemedAt()).isNotNull();
    assertThat(usedOld.getFailedAttempts()).isZero();
  }

  @Test
  @DisplayName("실패 응답은 코드 원문을 어디에도 싣지 않는다")
  void failureMessagesNeverEchoTheCode() {
    invite.setExpiresAt(LocalDateTime.now().minusSeconds(1));

    assertThatThrownBy(() -> service.redeem(Caller.guardian("J"), CODE, null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(e.getMessage()).doesNotContain(CODE));
    verify(profileInviteRepository, never()).save(any());
    verify(profileGuardianRepository, never()).delete(any());
    // 이 메서드 안에서 코드를 지우거나 새로 만들지 않는다
    verify(profileInviteRepository, never()).delete(any());
    verify(profileInviteRepository, never()).deleteAll(any());
    verify(profileInviteRepository, never()).findAllByProfileIdAndIssuedByAndRedeemedAtIsNullAndRevokedAtIsNull(
      eq("p1"), anyString());
  }
}
