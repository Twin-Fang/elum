package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.dto.request.MemberCharacterUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberConsentRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberSupportGoalsUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberConsentResponse;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
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

  private final ProfileRepository profileRepository;

  private final RoutineRepository routineRepository;

  private final AuthIdentityRepository authIdentityRepository;

  private final RefreshTokenRepository refreshTokenRepository;

  public MemberResponse getMyInfo(String memberId) {
    return MemberResponse.from(requireMember(memberId), findProfile(memberId));
  }

  @Transactional
  public MemberResponse updateNickname(String memberId, MemberNicknameUpdateRequest request) {
    Member member = requireMember(memberId);
    Profile profile = requireProfile(memberId);
    profile.setNickname(request.nickname());
    return MemberResponse.from(member, profile);
  }

  @Transactional
  public MemberResponse updateSupportGoals(String memberId, MemberSupportGoalsUpdateRequest request) {
    Member member = requireMember(memberId);
    Profile profile = requireProfile(memberId);
    profile.getSupportGoals().clear();
    profile.getSupportGoals().addAll(request.supportGoals());
    return MemberResponse.from(member, profile);
  }

  @Transactional
  public MemberResponse updateCharacter(String memberId, MemberCharacterUpdateRequest request) {
    Member member = requireMember(memberId);
    Profile profile = requireProfile(memberId);
    profile.setCharacter(request.character());
    return MemberResponse.from(member, profile);
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

  @Transactional
  public void withdraw(String memberId) {
    Member member = requireMember(memberId);

    // 일과 → 프로필 → 소셜 신원 → 세션 → 계정 순으로 지운다. 참조가 남으면 외래키가 걸린다.
    List<Routine> routines = routineRepository.findAllByProfileMemberId(memberId);
    routineRepository.deleteAll(routines);
    profileRepository.deleteAllByMemberId(memberId);
    authIdentityRepository.deleteAllByMemberId(memberId);
    // 리프레시 토큰은 member를 외래키로 참조하지 않아 DB가 대신 지워 주지 않는다.
    // 남겨 두면 탈퇴한 계정 ID로 갱신 요청이 계속 들어온다.
    refreshTokenRepository.deleteAllByMemberId(memberId);

    memberRepository.delete(member);
  }

  private Member requireMember(String memberId) {
    return memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }

  /**
   * 계정의 기본 프로필. 계정당 하나인 동안 기존 API가 당사자를 찾는 통로다.
   * 프로필이 여럿이 되면 호출부가 어느 프로필인지 명시하게 바꾼다.
   */
  private Profile requireProfile(String memberId) {
    return profileRepository.findFirstByMemberIdOrderByCreatedAtAsc(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }

  /** 조회 전용 — 프로필이 없어도 화면이 죽지 않게 null을 허용한다. */
  private Profile findProfile(String memberId) {
    return profileRepository.findFirstByMemberIdOrderByCreatedAtAsc(memberId).orElse(null);
  }
}
