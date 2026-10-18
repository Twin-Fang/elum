package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
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
  LocalDateTime createdAt,
  LocalDateTime withdrawnAt,
  LocalDateTime retentionExpiresAt,
  /// 지금 유효한 요금제 (만료된 Pro 는 FREE)
  PlanType plan,
  /// 유효한 Pro 의 만료일. 무기한이거나 Pro 가 아니면 null
  LocalDateTime planExpiresAt,
  /// 요금제 마지막 변경 시각·변경자. 이력이 없으면 null
  LocalDateTime planLastChangedAt,
  String planLastChangedBy
) {

  /// @param retentionExpiresAt 탈퇴 계정의 보관 만료 예정일. 탈퇴하지 않았으면 null
  /// @param subscription       구독 행. 없으면 null (Free 로 봄)
  /// @param lastPlanChange     요금제 마지막 변경 이력. 없으면 null
  public static AdminMemberResponse of(
    Member member, Profile profile, long routineCount, MemberAiUsage aiUsage,
    LocalDateTime retentionExpiresAt, Subscription subscription, SubscriptionHistory lastPlanChange
  ) {
    PlanType plan = subscription == null ? PlanType.FREE : subscription.effectivePlan(LocalDateTime.now());
    return new AdminMemberResponse(
      member.getId(),
      member.getUsername(),
      profile == null ? null : profile.getNickname(),
      profile == null ? null : profile.getCharacter(),
      member.getStatus(),
      profile == null ? Set.of() : profile.getSupportGoals(),
      profile == null ? 0 : profile.getTotalStars(),
      routineCount,
      aiUsage == null ? 0 : aiUsage.getCallCount(),
      aiUsage == null ? 0 : aiUsage.getTotalTokens(),
      aiUsage == null ? 0 : aiUsage.getTotalCostUsd(),
      member.getLastActivityAt(),
      member.getCreatedAt(),
      member.getWithdrawnAt(),
      retentionExpiresAt,
      plan,
      plan == PlanType.PRO ? subscription.getExpiresAt() : null,
      lastPlanChange == null ? null : lastPlanChange.getChangedAt(),
      lastPlanChange == null ? null : lastPlanChange.getChangedBy()
    );
  }
}
