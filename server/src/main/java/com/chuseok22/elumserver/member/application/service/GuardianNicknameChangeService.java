package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.core.NicknamePolicy;
import com.chuseok22.elumserver.member.core.NicknameVerdict;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 보호자 닉네임 변경: 정규화 > 같으면 그대로 > 형식·욕설·예약어 > 변경 주기 > 중복 > 반영
 * 저장(flush)과 유니크 경합 변환은 호출부 트랜잭션(MemberService)이 함
 */
@Slf4j
@Service
public class GuardianNicknameChangeService {

  // 다시 바꿀 수 있기까지 (첫 변경은 제한 없음)
  static final Duration CHANGE_INTERVAL = Duration.ofDays(7);

  private final MemberRepository memberRepository;
  private final NicknamePolicy nicknamePolicy;
  private final Clock clock;

  @Autowired
  public GuardianNicknameChangeService(MemberRepository memberRepository, NicknamePolicy nicknamePolicy) {
    this(memberRepository, nicknamePolicy, Clock.systemDefaultZone());
  }

  GuardianNicknameChangeService(MemberRepository memberRepository, NicknamePolicy nicknamePolicy, Clock clock) {
    this.memberRepository = memberRepository;
    this.nicknamePolicy = nicknamePolicy;
    this.clock = clock;
  }

  /**
   * 닉네임 변경 (실패는 CustomException: 형식, 쓸 수 없는 이름, 주기, 중복)
   */
  public void change(Member member, String rawNickname) {
    String nickname = nicknamePolicy.normalize(rawNickname);
    if (nickname.equals(member.getNickname())) {
      return;
    }
    rejectIfNotAllowed(member, nicknamePolicy.judge(nickname));
    rejectIfTooSoon(member);
    if (memberRepository.existsByNicknameIgnoreCaseAndIdNot(nickname, member.getId())) {
      reject(member, ErrorCode.NICKNAME_DUPLICATED);
    }
    member.setNickname(nickname);
    member.setNicknameChangedAt(LocalDateTime.now(clock));
    log.info("[member nickname] changed : memberId={}", member.getId());
  }

  /**
   * 다음에 바꿀 수 있는 시각 (바꾼 적 없으면 null = 지금 가능)
   */
  public static LocalDateTime changeableAt(Member member) {
    LocalDateTime changedAt = member.getNicknameChangedAt();
    return changedAt == null ? null : changedAt.plus(CHANGE_INTERVAL);
  }

  private void rejectIfNotAllowed(Member member, NicknameVerdict verdict) {
    if (verdict == NicknameVerdict.INVALID_FORMAT) {
      reject(member, ErrorCode.NICKNAME_INVALID_FORMAT);
    }
    if (verdict == NicknameVerdict.NOT_ALLOWED) {
      reject(member, ErrorCode.NICKNAME_NOT_ALLOWED);
    }
  }

  private void rejectIfTooSoon(Member member) {
    LocalDateTime changeableAt = changeableAt(member);
    if (changeableAt != null && LocalDateTime.now(clock).isBefore(changeableAt)) {
      reject(member, ErrorCode.NICKNAME_CHANGE_TOO_SOON);
    }
  }

  // 원문 닉네임은 로그에 남기지 않음 (사유 코드만)
  private void reject(Member member, ErrorCode errorCode) {
    log.info("[member nickname] rejected : memberId={}, reason={}", member.getId(), errorCode);
    throw new CustomException(errorCode);
  }
}
