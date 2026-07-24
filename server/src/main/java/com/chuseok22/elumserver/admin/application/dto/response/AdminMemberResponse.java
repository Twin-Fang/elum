package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.time.LocalDateTime;
import java.util.Set;

// 회원 목록 한 줄 — 프로필에 루틴수·AI 사용량·최근 활동을 붙여 운영 판단이 한 화면에서 되게 한다.
public record AdminMemberResponse(
  String id,
  String username,
  String nickname,
  CharacterType character,
  MemberStatus status,
  Set<SupportGoal> supportGoals,
  Integer totalStars,
  long routineCount,
  long aiCallCount,
  long totalTokens,
  double estimatedCostUsd,
  LocalDateTime lastActivityAt,
  LocalDateTime createdAt
) {

  public static AdminMemberResponse of(Member member, long routineCount, MemberAiUsage aiUsage) {
    return new AdminMemberResponse(
      member.getId(),
      member.getUsername(),
      member.getNickname(),
      member.getCharacter(),
      member.getStatus(),
      member.getSupportGoals(),
      member.getTotalStars(),
      routineCount,
      aiUsage == null ? 0 : aiUsage.getCallCount(),
      aiUsage == null ? 0 : aiUsage.getTotalTokens(),
      aiUsage == null ? 0 : aiUsage.getTotalCostUsd(),
      member.getLastActivityAt(),
      member.getCreatedAt()
    );
  }
}
