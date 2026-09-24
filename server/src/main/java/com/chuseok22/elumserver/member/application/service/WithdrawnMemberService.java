package com.chuseok22.elumserver.member.application.service;

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
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 탈퇴한 계정의 보관·되살리기·완전 삭제 (이슈 #372).
 *
 * <p>탈퇴({@link MemberService#withdraw})는 계정을 지우지 않고 WITHDRAWN 으로 남긴다. 완전히 지우면
 * 같은 소셜 계정으로 다시 가입해 무료 사용량을 0 부터 새로 받을 수 있어서다. 남기는 것은 재가입을
 * 알아볼 최소한 — 계정 행, 소셜 신원(이메일은 비움), AI 호출 기록의 회원 식별자뿐이다.
 *
 * <pre>
 *   탈퇴 ──▶ WITHDRAWN (보관) ──┬── 보관 기간 안에 같은 소셜 계정으로 로그인 ──▶ {@link #revive} (빈 상태, 한도 이어짐)
 *                               └── 보관 기간이 지남 · 관리자 즉시 삭제 ──────▶ {@link #purge} (완전 삭제)
 * </pre>
 *
 * <p>⚠️ 보관 기간은 개인정보처리방침에 적힌 기간과 같아야 한다. 방침 개정·고지 전에 운영에 내보내지 않는다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WithdrawnMemberService {

  private final MemberRepository memberRepository;
  private final ProfileRepository profileRepository;
  private final RoutineRepository routineRepository;
  private final AuthIdentityRepository authIdentityRepository;
  private final RefreshTokenRepository refreshTokenRepository;
  private final AiCallLogRepository aiCallLogRepository;
  private final DeviceLinkRepository deviceLinkRepository;
  private final SubscriptionRepository subscriptionRepository;
  private final SubscriptionService subscriptionService;
  private final SystemConfigService systemConfigService;

  /** 탈퇴 뒤 남겨 두는 일수. 관리자 설정값이다 (기본 365 — 개인정보처리방침 4조의 1년과 같다). */
  public int retentionDays() {
    return systemConfigService.getInt(ConfigKey.MEMBER_WITHDRAWN_RETENTION_DAYS);
  }

  /** 보관 만료 예정일. 탈퇴하지 않았거나 탈퇴 시각을 모르면 없다(null). */
  public LocalDateTime retentionExpiresAt(Member member) {
    if (member.getStatus() != MemberStatus.WITHDRAWN || member.getWithdrawnAt() == null) {
      return null;
    }
    return member.getWithdrawnAt().plusDays(retentionDays());
  }

  /**
   * 탈퇴 계정의 보관 기간이 지났는가. 탈퇴하지 않은 계정은 해당하지 않는다(false).
   *
   * <p>탈퇴 시각을 모르면 지난 것으로 본다 — 보관 기간 안이라고 말할 수 없는 것을 남겨 두면
   * 방침에 적은 기간을 넘겨 보관하게 된다.
   */
  public boolean isRetentionExpired(Member member) {
    if (member.getStatus() != MemberStatus.WITHDRAWN) {
      return false;
    }
    if (member.getWithdrawnAt() == null) {
      return true;
    }
    return !LocalDateTime.now().isBefore(member.getWithdrawnAt().plusDays(retentionDays()));
  }

  /**
   * 보관 중인 탈퇴 계정을 빈 상태로 되살린다 (S1).
   *
   * <p>새 계정을 만들지 않고 같은 행을 ACTIVE 로 돌린다. 회원 ID 가 같아야 AI 호출 기록이 이 계정의
   * 것으로 남아 하루·주간 한도가 이어진다. 이룸이·일과는 탈퇴 때 지웠으므로 돌아오지 않는다 —
   * 가입 때처럼 빈 프로필과 Free 구독만 만들어 온보딩부터 시작한다.
   */
  @Transactional
  public void revive(Member member) {
    member.setStatus(MemberStatus.ACTIVE);
    member.setWithdrawnAt(null);
    // 약관 동의는 다시 받는다. 비워 두면 앱이 가입 때처럼 동의 화면을 띄운다.
    member.clearConsents();
    // tokenInvalidBefore 는 그대로 둔다 — 비우면 탈퇴 전에 발급된 토큰이 되살아난다 (S4).

    // 가입 때와 같은 기본 프로필. 이름이 비어 있어 앱이 온보딩으로 보낸다.
    Profile profile = new Profile();
    profile.setMember(member);
    profile.setCharacter(CharacterType.LULU);
    profileRepository.save(profile);
    subscriptionService.createFreeIfAbsent(member);

    log.info("보관 중이던 탈퇴 계정을 되살렸습니다: memberId={}", member.getId());
  }

  /**
   * 탈퇴 계정을 완전히 지운다. 보관 기간이 지났을 때(스케줄러·로그인, S2·S7)와 관리자가 정보주체의
   * 삭제 요구를 받았을 때(S9) 쓴다.
   *
   * <p>탈퇴 상태가 아니면 지우지 않는다 — 대상을 고른 뒤 사이에 되살아났을 수 있다.
   * 이미 지워졌으면 할 일 없이 끝난다 — 스케줄러와 관리자 버튼이 겹쳐도 된다.
   */
  @Transactional
  public void purge(String memberId) {
    Member member = memberRepository.findById(memberId).orElse(null);
    if (member == null) {
      return;
    }
    if (member.getStatus() != MemberStatus.WITHDRAWN) {
      throw new CustomException(ErrorCode.MEMBER_NOT_WITHDRAWN);
    }

    // 탈퇴 때 이미 지운 것이지만 한 번 더 지운다. 남아 있으면 계정 행이 외래키에 걸려 삭제가 실패한다.
    routineRepository.deleteAll(routineRepository.findAllByProfileMemberId(memberId));
    profileRepository.deleteAllByMemberId(memberId);
    subscriptionRepository.deleteByMemberId(memberId);
    refreshTokenRepository.deleteAllByMemberId(memberId);
    deviceLinkRepository.deleteAllByMemberId(memberId);

    // 보관하던 것. 소셜 신원은 지우고, AI 호출 기록은 운영 지표라 행을 남기되 누가 썼는지를 뗀다 (#191).
    authIdentityRepository.deleteAllByMemberId(memberId);
    aiCallLogRepository.detachMember(memberId);

    memberRepository.delete(member);
    // 지우기를 바로 DB 에 보낸다. 로그인 경로(S2)는 같은 트랜잭션에서 같은 아이디로 새 계정을 만드는데,
    // Hibernate 는 넣기를 지우기보다 먼저 보내서 고유 제약(username, provider+provider_user_id)에 걸린다.
    memberRepository.flush();

    log.info("탈퇴 계정을 완전히 지웠습니다: memberId={}", memberId);
  }

  /** 보관 기간이 지난 탈퇴 계정 ID. 탈퇴 시각이 지금에서 보관 기간을 뺀 시각 이전이면 대상이다. */
  public List<String> findExpiredIds() {
    LocalDateTime threshold = LocalDateTime.now().minusDays(retentionDays());
    return memberRepository.findWithdrawnIdsUntil(MemberStatus.WITHDRAWN, threshold);
  }
}
