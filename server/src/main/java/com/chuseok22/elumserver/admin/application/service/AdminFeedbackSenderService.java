package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminFeedbackSenderPanel;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberCreditSummary;
import com.chuseok22.elumserver.admin.application.format.AdminLogIds;
import com.chuseok22.elumserver.ai.application.service.AiCallLogQueryService;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.member.application.service.MemberAdminLookupService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.time.Clock;
import java.time.LocalDateTime;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 의견 상세 "보낸 회원" 패널 조회: 회원 > 요금제 > 크레딧 요약 > 의견 시각 기준 최근 AI 호출
 * 트랜잭션을 두지 않음: 조회마다 각 서비스 트랜잭션 (크레딧 실패가 rollback-only 로 번지지 않게)
 */
@Slf4j
@Service
public class AdminFeedbackSenderService {

  /// AI 호출 조회 여유 시간 (의견 시각 + 30분): 의견을 보낸 직후 다시 시도한 호출까지 보이게
  static final long AI_CALL_WINDOW_AFTER_FEEDBACK_MINUTES = 30;

  private final MemberAdminLookupService memberAdminLookupService;
  private final SubscriptionService subscriptionService;
  private final AdminCreditQueryService adminCreditQueryService;
  private final AiCallLogQueryService aiCallLogQueryService;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시 (이 앱에는 Clock 빈이 없음)
  @Autowired
  public AdminFeedbackSenderService(
    MemberAdminLookupService memberAdminLookupService, SubscriptionService subscriptionService,
    AdminCreditQueryService adminCreditQueryService, AiCallLogQueryService aiCallLogQueryService
  ) {
    this(memberAdminLookupService, subscriptionService, adminCreditQueryService, aiCallLogQueryService,
      Clock.systemDefaultZone());
  }

  AdminFeedbackSenderService(
    MemberAdminLookupService memberAdminLookupService, SubscriptionService subscriptionService,
    AdminCreditQueryService adminCreditQueryService, AiCallLogQueryService aiCallLogQueryService, Clock clock
  ) {
    this.memberAdminLookupService = memberAdminLookupService;
    this.subscriptionService = subscriptionService;
    this.adminCreditQueryService = adminCreditQueryService;
    this.aiCallLogQueryService = aiCallLogQueryService;
    this.clock = clock;
  }

  /**
   * 회원 id + 의견 시각 > 패널 (회원이 없으면 memberNotFound)
   * 의견 시각이 없으면 지금 기준. 탈퇴 회원은 크레딧 요약 없음
   */
  public AdminFeedbackSenderPanel loadSenderPanel(String memberId, LocalDateTime feedbackCreatedAt) {
    Member member = memberAdminLookupService.findMember(memberId).orElse(null);
    if (member == null) {
      return AdminFeedbackSenderPanel.memberNotFound(memberId);
    }
    LocalDateTime now = LocalDateTime.now(clock);
    LocalDateTime aiCallsUntil = (feedbackCreatedAt == null ? now : feedbackCreatedAt)
      .plusMinutes(AI_CALL_WINDOW_AFTER_FEEDBACK_MINUTES);
    boolean isWithdrawn = member.getStatus() == MemberStatus.WITHDRAWN;
    return new AdminFeedbackSenderPanel(
      false,
      true,
      member.getId(),
      MemberAdminLookupService.displayNameOf(member),
      member.getStatus(),
      effectivePlanOf(member.getId(), now),
      isWithdrawn ? null : creditSummaryOf(member.getId()),
      aiCallLogQueryService.findRecentCallsOfMemberUntil(member.getId(), aiCallsUntil),
      aiCallsUntil
    );
  }

  // 구독 행이 없거나 만료면 무료
  private PlanType effectivePlanOf(String memberId, LocalDateTime now) {
    return subscriptionService.find(memberId)
      .map(subscription -> subscription.effectivePlan(now))
      .orElse(PlanType.FREE);
  }

  // 크레딧 실패는 크레딧 칸만 안내 (패널의 나머지는 그대로)
  private AdminMemberCreditSummary creditSummaryOf(String memberId) {
    try {
      return adminCreditQueryService.memberCreditSummary(memberId);
    } catch (RuntimeException e) {
      log.warn("[admin feedback] sender credit summary failed : memberId={}", AdminLogIds.toLoggableId(memberId), e);
      return AdminMemberCreditSummary.loadFailed();
    }
  }
}
