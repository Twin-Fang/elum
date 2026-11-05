package com.chuseok22.elumserver.member;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.application.service.GuardianshipService;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.member.application.service.WithdrawnMemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberDailyVisit;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberDailyVisitRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * 실제 Postgres·영속성 컨텍스트로 하는 탈퇴 리허설 (#1143). 평소 빌드에서는 건너뛴다.
 * 목 테스트는 일괄 쿼리의 영속성 컨텍스트 비움(clearAutomatically)으로 계정 행 변경이 버려지는 것을 못 잡는다.
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:55143/elum ./gradlew test --tests '*MemberWithdrawRehearsalIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.flyway.enabled=false",
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=elum",
  "spring.datasource.password=pw",
  "gemini.api-key=rehearsal-invalid"
})
@ActiveProfiles("dev")
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class MemberWithdrawRehearsalIT {

  @Autowired private MemberService memberService;
  @Autowired private WithdrawnMemberService withdrawnMemberService;
  @Autowired private GuardianshipService guardianshipService;
  @Autowired private MemberRepository memberRepository;
  @Autowired private MemberDailyVisitRepository memberDailyVisitRepository;

  @Test
  @DisplayName("탈퇴하면 계정 행이 WITHDRAWN 으로 바뀌고 탈퇴 시각·토큰 무효 시각이 저장된다 (방문 기록이 있어도)")
  void withdrawPersistsMemberStatus() {
    Member member = newVisitedMember();
    LocalDateTime beforeWithdraw = LocalDateTime.now().minusSeconds(1);

    memberService.withdraw(member.getId());

    // 새 트랜잭션에서 다시 읽음 (영속성 컨텍스트 캐시가 아닌 DB 값)
    Member stored = memberRepository.findById(member.getId()).orElseThrow();
    assertThat(stored.getStatus()).isEqualTo(MemberStatus.WITHDRAWN);
    assertThat(stored.getWithdrawnAt()).isAfter(beforeWithdraw);
    assertThat(stored.getTokenInvalidBefore()).isAfter(beforeWithdraw);
    assertThat(stored.getLoginCount()).isZero();
    assertThat(stored.getLastLoginAt()).isNull();
    assertThat(memberDailyVisitRepository.findAll())
      .noneMatch(visit -> visit.getMemberId().equals(member.getId()));
  }

  @Test
  @DisplayName("탈퇴한 계정을 완전 삭제하면 계정 행이 사라진다")
  void purgeDeletesWithdrawnMember() {
    Member member = newVisitedMember();
    memberService.withdraw(member.getId());

    withdrawnMemberService.purge(member.getId());

    assertThat(memberRepository.findById(member.getId())).isEmpty();
  }

  // ── 준비물 ──

  // 가입 직후 모양: 기본 이룸이 + 로그인 기록 + 오늘 방문 기록 1건
  private Member newVisitedMember() {
    Member member = new Member();
    member.setUsername("it1143_" + UUID.randomUUID());
    member.setPassword("x");
    member.setTermsAgreed(true);
    member.setPrivacyAgreed(true);
    member.setOverseasTransferAgreed(true);
    member.setGuardianConfirmed(true);
    member.setLoginCount(1);
    member.setLastLoginAt(LocalDateTime.now());
    Member saved = memberRepository.save(member);
    guardianshipService.createOwnProfile(saved);
    MemberDailyVisit visit = new MemberDailyVisit();
    visit.setMemberId(saved.getId());
    visit.setVisitDate(LocalDate.now());
    memberDailyVisitRepository.save(visit);
    return saved;
  }
}
