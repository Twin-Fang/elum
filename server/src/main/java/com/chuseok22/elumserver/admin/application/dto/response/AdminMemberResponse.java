package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.time.LocalDateTime;
import java.util.Set;

public record AdminMemberResponse(
  String id,
  String username,
  String nickname,
  Set<SupportGoal> supportGoals,
  Integer totalStars,
  LocalDateTime createdAt
) {

  public static AdminMemberResponse from(Member member) {
    return new AdminMemberResponse(
      member.getId(),
      member.getUsername(),
      member.getNickname(),
      member.getSupportGoals(),
      member.getTotalStars(),
      member.getCreatedAt()
    );
  }
}
