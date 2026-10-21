package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.core.MemberAdminMemoSaveResult;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 회원 운영 메모 저장 규칙 (#656)
 * 깨지면 2,000자 넘는 메모가 저장되거나, 비운 메모가 지워지지 않거나, 줄바꿈 때문에 상한 안의 메모가 거절된다
 */
class MemberAdminMemoServiceTest {

  private static final Clock FIXED_CLOCK = Clock.fixed(Instant.parse("2026-10-22T00:00:00Z"), ZoneId.of("Asia/Seoul"));

  @Test
  @DisplayName("상한 초과는 저장 없이 거절, CRLF 는 LF 로 세어 상한 안이면 저장, 공백뿐이면 지우고 변경자·시각을 남긴다")
  void appliesLengthAndBlankRules() {
    Member member = activeMember();
    MemberRepository memberRepository = mock(MemberRepository.class);
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    MemberAdminMemoService service = new MemberAdminMemoService(memberRepository, FIXED_CLOCK);

    // 상한 초과 > 거절, 값 그대로
    String tooLong = "가".repeat(MemberAdminMemoService.MAX_ADMIN_MEMO_LENGTH + 1);
    assertThat(service.saveAdminMemo("m1", tooLong, "admin")).isEqualTo(MemberAdminMemoSaveResult.REJECTED_TOO_LONG);
    assertThat(member.getAdminMemo()).isNull();

    // CRLF 를 LF 로 세면 정확히 상한 > 저장
    String crlfMemo = "가".repeat(MemberAdminMemoService.MAX_ADMIN_MEMO_LENGTH - 2) + "\r\n가";
    assertThat(service.saveAdminMemo("m1", crlfMemo, "admin")).isEqualTo(MemberAdminMemoSaveResult.SAVED);
    assertThat(member.getAdminMemo()).hasSize(MemberAdminMemoService.MAX_ADMIN_MEMO_LENGTH).doesNotContain("\r");

    // 공백뿐 > 지움 + 변경 기록
    assertThat(service.saveAdminMemo("m1", "  \r\n ", "admin2")).isEqualTo(MemberAdminMemoSaveResult.CLEARED);
    assertThat(member.getAdminMemo()).isNull();
    assertThat(member.getAdminMemoChangedBy()).isEqualTo("admin2");
    assertThat(member.getAdminMemoChangedAt()).isEqualTo(LocalDateTime.now(FIXED_CLOCK));
  }

  @Test
  @DisplayName("탈퇴 회원에는 메모를 저장하지 않는다 (방침 4조 보관 항목이 아님)")
  void rejectsWithdrawnMember() {
    Member member = activeMember();
    member.setStatus(MemberStatus.WITHDRAWN);
    MemberRepository memberRepository = mock(MemberRepository.class);
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    assertThat(new MemberAdminMemoService(memberRepository, FIXED_CLOCK).saveAdminMemo("m1", "메모", "admin"))
      .isEqualTo(MemberAdminMemoSaveResult.REJECTED_WITHDRAWN);
    assertThat(member.getAdminMemo()).isNull();
  }

  private static Member activeMember() {
    Member member = new Member();
    member.setId("m1");
    member.setStatus(MemberStatus.ACTIVE);
    return member;
  }
}
