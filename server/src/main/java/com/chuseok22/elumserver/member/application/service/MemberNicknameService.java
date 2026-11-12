package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.util.concurrent.ThreadLocalRandom;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 보호자 닉네임: 자동 생성, 중복 회피, 비어 있는 계정에 부여
 * 형식: 보호자-숫자 (예: 보호자-1269). 무작위 단어 별명은 장난스럽게 읽혀 쓰지 않음 (#1304). 유니크는 DB 인덱스가 최종 보장
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class MemberNicknameService {

  // 자동 닉네임 앞부분 (아이 이름은 가입 시점에 모르고, 이야기 탭에 공개되므로 넣지 않음)
  static final String DEFAULT_NICKNAME_PREFIX = "보호자";
  private static final String NUMBER_DELIMITER = "-";
  // 짧은 숫자 자릿수
  private static final int SHORT_NUMBER_LENGTH = 4;
  // 4자리로 겹칠 때 다시 뽑는 횟수
  private static final int MAX_ATTEMPTS_WITH_SHORT_NUMBER = 5;
  // 재추첨이 모두 겹쳤을 때 쓰는 긴 숫자 자릿수
  private static final int FALLBACK_NUMBER_LENGTH = 8;

  private final MemberRepository memberRepository;

  /**
   * 닉네임 없으면 생성해 넣음 (있으면 그대로, 기존 가입자 이름은 바꾸지 않음). 저장은 호출부 트랜잭션이 함
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
      String candidate = toNumberedNickname(SHORT_NUMBER_LENGTH);
      if (!memberRepository.existsByNickname(candidate)) {
        return candidate;
      }
    }
    log.info("[member nickname] short candidates exhausted, fallback to long number");
    return toNumberedNickname(FALLBACK_NUMBER_LENGTH);
  }

  /**
   * 자릿수 > `보호자-{첫 자리 0 아닌 숫자}` (예: 4 > 보호자-1269)
   */
  private static String toNumberedNickname(int numberLength) {
    long lowerBound = (long) Math.pow(10, numberLength - 1);
    long upperBound = lowerBound * 10;
    long number = ThreadLocalRandom.current().nextLong(lowerBound, upperBound);
    return DEFAULT_NICKNAME_PREFIX + NUMBER_DELIMITER + number;
  }
}
