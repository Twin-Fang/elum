package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

public record AdminMemberDetailResponse(
  String id,
  String username,
  String nickname,
  Set<SupportGoal> supportGoals,
  Integer totalStars,
  LocalDateTime createdAt,
  List<AdminMemberRoutineSummary> routines
) {

  public static AdminMemberDetailResponse of(Member member, List<Routine> routines) {
    List<AdminMemberRoutineSummary> routineSummaries = routines.stream()
      .map(AdminMemberRoutineSummary::from)
      .toList();
    return new AdminMemberDetailResponse(
      member.getId(),
      member.getUsername(),
      member.getNickname(),
      member.getSupportGoals(),
      member.getTotalStars(),
      member.getCreatedAt(),
      routineSummaries
    );
  }
}
