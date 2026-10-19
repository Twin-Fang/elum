package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import me.suhsaechan.suhnicknamegenerator.core.SuhRandomKit;
import org.springframework.stereotype.Service;

/**
 * 보호자 닉네임: 자동 생성, 중복 회피, 비어 있는 계정에 부여
 * 형식: 형용사+명사-숫자 (예: 가파른블록-1269). 유니크는 DB 인덱스가 최종 보장
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class MemberNicknameService {

  // 4자리로 겹칠 때 다시 뽑는 횟수
  private static final int MAX_ATTEMPTS_WITH_SHORT_NUMBER = 5;
  // 재추첨이 모두 겹쳤을 때 쓰는 긴 숫자 자릿수
  private static final int FALLBACK_NUMBER_LENGTH = 8;

  private static final SuhRandomKit NICKNAME_KIT = SuhRandomKit.builder().locale("ko").build();

  private final MemberRepository memberRepository;

  /**
   * 닉네임 없으면 생성해 넣음 (있으면 그대로). 저장은 호출부 트랜잭션이 함
   */
  public void assignIfAbsent(Member member) {
    if (member.getNickname() != null) {
      return;
    }
    member.setNickname(generateUniqueNickname());
  }

  /**
   * 겹치지 않는 닉네임: 4자리 최대 5회 > 8자리 1회
   */
  public String generateUniqueNickname() {
    for (int attempt = 0; attempt < MAX_ATTEMPTS_WITH_SHORT_NUMBER; attempt++) {
      String candidate = NICKNAME_KIT.nicknameWithNumber();
      if (!memberRepository.existsByNickname(candidate)) {
        return candidate;
      }
    }
    log.info("[member nickname] short candidates exhausted, fallback to long number");
    return NICKNAME_KIT.nicknameWithNumber(FALLBACK_NUMBER_LENGTH);
  }
}
