package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import com.chuseok22.elumserver.member.core.MemberAccountKindChange;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원 계정 종류 (관리자 전용, #1436): 종류 바꾸기 + 변경 시각·관리자, 분류 제안 "일반 맞음" 확인
 * 자동 분류 없음: 모든 변경은 관리자 버튼으로만. 없는 회원은 MEMBER_NOT_FOUND
 */
@Service
public class MemberAccountKindService {

  private final MemberRepository memberRepository;
  private final Clock clock;

  @Autowired
  public MemberAccountKindService(MemberRepository memberRepository) {
    this(memberRepository, Clock.systemDefaultZone());
  }

  MemberAccountKindService(MemberRepository memberRepository, Clock clock) {
    this.memberRepository = memberRepository;
    this.clock = clock;
  }

  /** 종류 바꾸기 > 전후 종류 (같은 종류면 저장하지 않음) */
  @Transactional
  public MemberAccountKindChange changeAccountKind(String memberId, MemberAccountKind newKind, String actor) {
    Member member = findOrThrow(memberId);
    MemberAccountKind previousKind = member.getAccountKind();
    if (previousKind != newKind) {
      member.setAccountKind(newKind);
      member.setAccountKindChangedAt(LocalDateTime.now(clock));
      member.setAccountKindChangedBy(actor);
    }
    return new MemberAccountKindChange(previousKind, newKind);
  }

  /** 분류 제안 숨김: "일반 맞음" 확인 시각 기록 (다시 제안하지 않음) */
  @Transactional
  public void markReviewedAsNormal(String memberId) {
    findOrThrow(memberId).setAccountKindReviewedAt(LocalDateTime.now(clock));
  }

  private Member findOrThrow(String memberId) {
    return memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }
}
