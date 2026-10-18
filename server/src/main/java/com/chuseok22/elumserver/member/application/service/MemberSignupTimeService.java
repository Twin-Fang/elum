package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원 가입 시각 조회: 다른 도메인이 회원 repository 를 직접 쓰지 않게 하는 창구
 */
@Service
@RequiredArgsConstructor
public class MemberSignupTimeService {

  private final MemberRepository memberRepository;

  // 회원 id > 가입 시각 (회원이 없으면 비어 있음)
  @Transactional(readOnly = true)
  public Optional<LocalDateTime> findSignupAt(String memberId) {
    return memberRepository.findById(memberId).map(Member::getCreatedAt);
  }
}
