package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.application.dto.request.MemberCharacterUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberConsentRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberSupportGoalsUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberConsentResponse;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberService {

  private final MemberRepository memberRepository;

  private final ProfileAccessGuard profileAccessGuard;

  private final GuardianshipService guardianshipService;

  private final AuthIdentityRepository authIdentityRepository;

  private final RefreshTokenRepository refreshTokenRepository;

  private final DeviceLinkRepository deviceLinkRepository;
  private final SubscriptionRepository subscriptionRepository;
  private final EntitlementService entitlementService;

  /**
   * 내 정보. 헤더로 이룸이를 짚었으면 그 이룸이(연결 안 됐으면 403), 아니면 가장 먼저 연결된 이룸이.
   *
   * <p>연결된 이룸이가 없으면(E29) 당사자 칸을 비워 응답한다 — 화면이 죽지 않고 앱이 온보딩으로 보낸다.
   */
  public MemberResponse getMyInfo(Caller caller) {
    Member member = requireMember(caller.memberId());
    List<Profile> profiles = profileAccessGuard.profilesOf(caller);
    Profile current = caller.profileId() != null
      ? profileAccessGuard.profileFor(caller, ProfileAction.VIEW)
      : profiles.stream().findFirst().orElse(null);
    return MemberResponse.from(member, current, profiles, entitlementService.snapshot(caller.memberId()));
  }

  // 이룸이 정보는 연결된 보호자 누구나 고친다. 마지막에 바꾼 값이 남는다 (명세 2장 · E23).
  @Transactional
  public MemberResponse updateNickname(Caller caller, MemberNicknameUpdateRequest request) {
    Member member = requireMember(caller.memberId());
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    profile.setNickname(request.nickname());
    return MemberResponse.from(
      member, profile, profileAccessGuard.profilesOf(caller), entitlementService.snapshot(caller.memberId()));
  }

  @Transactional
  public MemberResponse updateSupportGoals(Caller caller, MemberSupportGoalsUpdateRequest request) {
    Member member = requireMember(caller.memberId());
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    profile.getSupportGoals().clear();
    profile.getSupportGoals().addAll(request.supportGoals());
    return MemberResponse.from(
      member, profile, profileAccessGuard.profilesOf(caller), entitlementService.snapshot(caller.memberId()));
  }

  @Transactional
  public MemberResponse updateCharacter(Caller caller, MemberCharacterUpdateRequest request) {
    Member member = requireMember(caller.memberId());
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    profile.setCharacter(request.character());
    return MemberResponse.from(
      member, profile, profileAccessGuard.profilesOf(caller), entitlementService.snapshot(caller.memberId()));
  }

  public MemberConsentResponse getConsents(String memberId) {
    return MemberConsentResponse.from(requireMember(memberId));
  }

  /**
   * 약관 동의를 기록한다.
   *
   * <p>항목을 하나로 뭉치지 않고 따로 저장한다. 개인정보보호법은 필수와 선택을
   * 분리해 받도록 하며, 뭉쳐서 받은 동의는 무효가 될 수 있다.
   *
   * <p><b>동의 시각을 반드시 남긴다.</b> "언제 동의받았는가"를 답하지 못하면
   * 동의 자체를 입증할 수 없다. 재동의(약관 개정) 때도 이 값으로 갱신 시점을 남긴다.
   */
  @Transactional
  public MemberConsentResponse agreeConsents(String memberId, MemberConsentRequest request) {
    Member member = requireMember(memberId);

    member.setTermsAgreed(request.termsAgreed());
    member.setPrivacyAgreed(request.privacyAgreed());
    member.setOverseasTransferAgreed(request.overseasTransferAgreed());
    member.setGuardianConfirmed(request.guardianConfirmed());
    // 선택 항목은 동의하지 않아도 그대로 저장한다 — 거부 의사도 기록이다.
    member.setMarketingAgreed(request.marketingAgreed());
    member.setConsentedAt(LocalDateTime.now());
    member.setConsentVersion(request.consentVersion());

    return MemberConsentResponse.from(member);
  }

  /**
   * 탈퇴. 계정을 지우지 않고 WITHDRAWN 으로 남긴다 (이슈 #372).
   *
   * <p>완전히 지우면 같은 소셜 계정으로 다시 가입해 무료 사용량을 0 부터 새로 받을 수 있다.
   * 그래서 재가입을 알아볼 최소한만 보관 기간 동안 남기고, 나머지는 지금처럼 즉시 지운다.
   * 보관 기간이 지나면 남긴 것도 지운다({@link WithdrawnMemberService#purge}).
   *
   * <p>한 트랜잭션이라 도중에 실패하면 전부 되돌린다 (S5). 상태는 맨 마지막에 바꾼다.
   */
  @Transactional
  public void withdraw(String memberId) {
    Member member = requireMember(memberId);

    // ── 지운다 ──
    // 연결된 이룸이마다 "나가기"를 한다 (다중 보호자 명세 4-3, #360). 내가 만든 일과·내가 붙인 이룸이 휴대폰·
    // 관계를 지우고, 혼자 돌보던 이룸이는 이룸이 정보까지 지운다 — 발달장애 당사자에 대한 서술이라 오래 둘수록
    // 위험하고, 악용 방지에는 필요 없다. 다른 보호자와 함께 돌보던 이룸이와 그들의 일과는 남는다.
    // 대표 보호자(profile.member_id)도 남은 사람에게 넘어가므로 보관 중인 이 계정 행을 가리키는 이룸이가 없다.
    guardianshipService.leaveAll(memberId);
    // 세션. member를 외래키로 참조하지 않아 DB가 대신 지워 주지 않는다.
    refreshTokenRepository.deleteAllByMemberId(memberId);
    // 이룸이 휴대폰 연결 (이슈 #200). 되살아나도 예전 휴대폰은 새 연결 암호로만 붙는다 (S8).
    deviceLinkRepository.deleteAllByMemberId(memberId);
    // 구독. 되살릴 때 가입처럼 Free 로 새로 만든다.
    subscriptionRepository.deleteByMemberId(memberId);

    // ── 남긴다 (보관 기간 동안) ──
    // 소셜 신원: 같은 소셜 계정이 다시 오면 이 행으로 이전 계정을 찾는다. 이메일은 비운다 —
    // 재가입 판별에 쓰지 않고, 남겨 두면 다른 제공자로 새로 가입할 때 이메일 충돌로 막힌다 (S3).
    authIdentityRepository.findAllByMemberId(memberId).forEach(identity -> {
      identity.setEmail(null);
      identity.setEmailVerified(false);
    });
    // AI 호출 기록: 회원 식별자를 그대로 둔다. 떼면 재가입한 계정의 하루·주간 사용량이 0 이 된다.
    // 식별자는 보관 기간이 지나 완전히 지울 때 뗀다.

    // 계정 행: 상태만 바꾼다. 맨 마지막에 둔다 — 앞에서 실패하면 상태가 바뀌지 않은 채 되돌아간다.
    LocalDateTime now = LocalDateTime.now();
    member.setStatus(MemberStatus.WITHDRAWN);
    member.setWithdrawnAt(now);
    // 이미 발급된 액세스 토큰도 즉시 막는다 (S4). 되살아나도 이 값은 그대로라 탈퇴 전 토큰은 계속 막힌다.
    member.setTokenInvalidBefore(now);
    // 재가입 판별에 필요 없는 활동 기록은 비운다 (최소 보관). 방침 4조 보관 항목에 없는 값이다.
    // 로그인 횟수는 not null 열이라 0 으로 둔다 — 되살리면 로그인하면서 1 부터 다시 센다.
    member.setLastLoginAt(null);
    member.setLastActivityAt(null);
    member.setLoginCount(0);
    // 남기는 값: 아이디·비밀번호 변환값(1년 안 같은 아이디로 복원), 동의 기록(값·시각·버전 — 동의 증빙).
    // 둘 다 방침 4조 보관 항목이다. 여기서 남기는 값을 늘리면 방침도 함께 고친다.
  }

  /** 탈퇴한 계정은 없는 회원으로 본다 — 탈퇴 전 행을 지우던 때와 같은 응답이다. */
  private Member requireMember(String memberId) {
    return memberRepository.findById(memberId)
      .filter(member -> member.getStatus() != MemberStatus.WITHDRAWN)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }
}
