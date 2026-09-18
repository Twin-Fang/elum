package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

public record AdminMemberDetailResponse(
  String id,
  String username,
  String nickname,
  CharacterType character,
  MemberStatus status,
  Set<SupportGoal> supportGoals,
  Integer totalStars,
  LocalDateTime createdAt,
  LocalDateTime lastLoginAt,
  LocalDateTime lastActivityAt,
  Integer loginCount,
  long aiCallCount,
  long totalTokens,
  double estimatedCostUsd,
  List<AdminMemberRoutineSummary> routines,
  List<AiCallLog> recentAiCalls,
  AdminSubscriptionSummary subscription
) {

  public static AdminMemberDetailResponse of(
    Member member, Profile profile, List<Routine> routines, MemberAiUsage aiUsage,
    List<AiCallLog> recentAiCalls, AdminSubscriptionSummary subscription
  ) {
    List<AdminMemberRoutineSummary> routineSummaries = routines.stream()
      .map(AdminMemberRoutineSummary::from)
      .toList();
    return new AdminMemberDetailResponse(
      member.getId(),
      member.getUsername(),
      profile == null ? null : profile.getNickname(),
      profile == null ? null : profile.getCharacter(),
      member.getStatus(),
      profile == null ? Set.of() : profile.getSupportGoals(),
      profile == null ? 0 : profile.getTotalStars(),
      member.getCreatedAt(),
      member.getLastLoginAt(),
      member.getLastActivityAt(),
      member.getLoginCount(),
      aiUsage == null ? 0 : aiUsage.getCallCount(),
      aiUsage == null ? 0 : aiUsage.getTotalTokens(),
      aiUsage == null ? 0 : aiUsage.getTotalCostUsd(),
      routineSummaries,
      recentAiCalls,
      subscription
    );
  }

  // 루틴 상태별 개수 — 템플릿에서 바로 쓰는 헬퍼.
  public long routineCountOf(String statusName) {
    return routines.stream().filter(routine -> routine.status().name().equals(statusName)).count();
  }
}
