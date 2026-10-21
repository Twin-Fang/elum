package com.chuseok22.elumserver.member.infrastructure.config;

import com.chuseok22.elumserver.member.application.service.MemberNicknameService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * 기동 시 닉네임 없는 계정(V46 이전 가입자)에 닉네임 부여
 * 건별 저장 > 한 건 실패해도 나머지 진행, 다음 기동 때 다시 시도
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class MemberNicknameBackfill implements ApplicationRunner {

  private final MemberRepository memberRepository;
  private final MemberNicknameService memberNicknameService;

  @Override
  public void run(ApplicationArguments args) {
    List<Member> membersWithoutNickname = memberRepository.findAllByNicknameIsNull();
    if (membersWithoutNickname.isEmpty()) {
      return;
    }
    int filledCount = 0;
    for (Member member : membersWithoutNickname) {
      try {
        memberNicknameService.assignIfAbsent(member);
        memberRepository.saveAndFlush(member);
        filledCount++;
      } catch (RuntimeException e) {
        // 동시 기동(blue/green)으로 같은 값이 겹친 경우 등 — 다음 기동 때 다시 채움
        log.warn("[member nickname] backfill failed : memberId={}, cause={}", member.getId(), e.getClass().getSimpleName());
        member.setNickname(null);
      }
    }
    log.info("[member nickname] backfill done : {}/{}", filledCount, membersWithoutNickname.size());
  }
}
