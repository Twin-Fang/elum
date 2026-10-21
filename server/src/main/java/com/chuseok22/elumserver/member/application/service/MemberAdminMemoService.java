package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.core.MemberAdminMemoSaveResult;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원 운영 메모(관리자 전용): 길이 검사 > 저장 또는 지움 + 변경 시각·관리자 기록 (#656)
 * 규칙은 의견 관리자 메모(FeedbackService.saveAdminNote)와 같음: 2,000자 상한, 비우면 지움
 */
@Service
public class MemberAdminMemoService {

  /// 운영 메모 최대 글자 수 (줄바꿈 LF 기준)
  public static final int MAX_ADMIN_MEMO_LENGTH = 2000;

  private final MemberRepository memberRepository;
  private final Clock clock;

  @Autowired
  public MemberAdminMemoService(MemberRepository memberRepository) {
    this(memberRepository, Clock.systemDefaultZone());
  }

  MemberAdminMemoService(MemberRepository memberRepository, Clock clock) {
    this.memberRepository = memberRepository;
    this.clock = clock;
  }

  /**
   * 메모 저장: 정리(CRLF > LF, 앞뒤 공백) > 길이 초과면 거절 > 탈퇴 회원이면 거절 > 저장(빈 값이면 지움)
   * 탈퇴 회원은 보관 항목(방침 4조)이 아니라 메모를 받지 않음. 없는 회원은 MEMBER_NOT_FOUND
   */
  @Transactional
  public MemberAdminMemoSaveResult saveAdminMemo(String memberId, String memo, String actor) {
    // 폼 전송은 줄바꿈을 CRLF 로 보내 브라우저 maxlength 보다 길어짐 > LF 로 맞춘 뒤 셈
    String trimmedMemo = memo == null ? "" : memo.replace("\r\n", "\n").strip();
    if (trimmedMemo.length() > MAX_ADMIN_MEMO_LENGTH) {
      return MemberAdminMemoSaveResult.REJECTED_TOO_LONG;
    }
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
    if (member.getStatus() == MemberStatus.WITHDRAWN) {
      return MemberAdminMemoSaveResult.REJECTED_WITHDRAWN;
    }
    member.setAdminMemo(trimmedMemo.isEmpty() ? null : trimmedMemo);
    member.setAdminMemoChangedAt(LocalDateTime.now(clock));
    member.setAdminMemoChangedBy(actor);
    return trimmedMemo.isEmpty() ? MemberAdminMemoSaveResult.CLEARED : MemberAdminMemoSaveResult.SAVED;
  }
}
