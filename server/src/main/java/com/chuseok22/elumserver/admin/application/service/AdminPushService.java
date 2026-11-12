package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.request.AdminPushRequest;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushPreviewResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushSendResponse;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminPushOutcome;
import com.chuseok22.elumserver.ai.application.service.AiCallLogQueryService;
import com.chuseok22.elumserver.member.application.service.MemberAdminLookupService;
import com.chuseok22.elumserver.notification.application.service.AdminMessageReach;
import com.chuseok22.elumserver.notification.application.service.AdminMessageSendResult;
import com.chuseok22.elumserver.notification.application.service.AdminMessageService;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 관리자 알림 보내기 (#1273): 대상 미리 계산, 먼저 보내 보기(한 명), 보내기
 * 보내기 검사 순서: 내용 > 야간(21~08시) > 받는 사람 > 인원(1~1,000명) > 발송 > 관리자 기록
 */
@Slf4j
@Service
public class AdminPushService {

  // 한 번에 보낼 수 있는 최대 회원 수
  public static final int MAXIMUM_RECIPIENT_COUNT = 1000;
  // 보내기를 막는 시간 [21:00, 다음 날 08:00) KST (먼저 보내 보기는 막지 않음)
  static final LocalTime QUIET_HOURS_START = LocalTime.of(21, 0);
  static final LocalTime QUIET_HOURS_END = LocalTime.of(8, 0);
  // 받는 사람 고르는 방식 2개: 고른 회원, 조건
  static final String TARGET_MODE_MEMBERS = "MEMBERS";
  static final String TARGET_MODE_CONDITION = "CONDITION";
  // 관리자 기록 detail 에 넣는 제목 앞부분 길이
  private static final int AUDIT_TITLE_PREVIEW_LENGTH = 40;

  private final MemberAdminLookupService memberAdminLookupService;
  private final AiCallLogQueryService aiCallLogQueryService;
  private final AdminMessageService adminMessageService;
  private final AdminAuditService adminAuditService;
  private final Clock clock;

  @Autowired
  public AdminPushService(MemberAdminLookupService memberAdminLookupService,
    AiCallLogQueryService aiCallLogQueryService, AdminMessageService adminMessageService,
    AdminAuditService adminAuditService) {
    this(memberAdminLookupService, aiCallLogQueryService, adminMessageService, adminAuditService,
      Clock.system(NotificationTime.ZONE_ID));
  }

  AdminPushService(MemberAdminLookupService memberAdminLookupService, AiCallLogQueryService aiCallLogQueryService,
    AdminMessageService adminMessageService, AdminAuditService adminAuditService, Clock clock) {
    this.memberAdminLookupService = memberAdminLookupService;
    this.aiCallLogQueryService = aiCallLogQueryService;
    this.adminMessageService = adminMessageService;
    this.adminAuditService = adminAuditService;
    this.clock = clock;
  }

  /// 대상 미리 계산: 받는 사람 > 인원 판정 > 알림 켠 사람·기기 수 (상한을 넘어도 수는 보여 줌)
  public AdminPushPreviewResponse preview(AdminPushRequest request) {
    boolean isQuietHours = isQuietHoursNow();
    TargetResolution targets = resolveTargets(request);
    if (targets.rejection().isPresent()) {
      return AdminPushPreviewResponse.of(targets.rejection().get(), 0, 0, 0, MAXIMUM_RECIPIENT_COUNT, isQuietHours);
    }
    List<String> memberIds = targets.memberIds();
    AdminMessageReach reach = adminMessageService.reachOf(memberIds);
    return AdminPushPreviewResponse.of(recipientCountOutcomeOf(memberIds.size()).orElse(AdminPushOutcome.READY),
      reach.memberCount(), reach.pushEnabledMemberCount(), reach.deviceCount(), MAXIMUM_RECIPIENT_COUNT,
      isQuietHours);
  }

  /// 보내기: 내용 > 야간 > 받는 사람 > 인원 검사 > 발송 > 관리자 기록 (거절은 사유만 돌려줌, 아무것도 저장 안 함)
  public AdminPushSendResponse send(AdminPushRequest request) {
    Optional<AdminMessageRoute> route = validMessageRouteOf(request);
    if (route.isEmpty()) {
      return AdminPushSendResponse.rejected(AdminPushOutcome.INVALID_MESSAGE);
    }
    if (isQuietHoursNow()) {
      return AdminPushSendResponse.rejected(AdminPushOutcome.QUIET_HOURS);
    }
    TargetResolution targets = resolveTargets(request);
    if (targets.rejection().isPresent()) {
      return AdminPushSendResponse.rejected(targets.rejection().get());
    }
    Optional<AdminPushOutcome> countRejection = recipientCountOutcomeOf(targets.memberIds().size());
    if (countRejection.isPresent()) {
      return AdminPushSendResponse.rejected(countRejection.get());
    }
    return sendAndRecord(request, route.get(), targets.memberIds(), AdminAuditAction.ADMIN_PUSH_SENT);
  }

  /// 먼저 보내 보기: 내용 > 받을 회원 한 명(활성) 검사 > 발송 > 관리자 기록 (야간에도 보냄)
  public AdminPushSendResponse sendTest(AdminPushRequest request) {
    Optional<AdminMessageRoute> route = validMessageRouteOf(request);
    if (route.isEmpty()) {
      return AdminPushSendResponse.rejected(AdminPushOutcome.INVALID_MESSAGE);
    }
    String testMemberId = request.testMemberId() == null ? "" : request.testMemberId().strip();
    List<String> activeMemberIds = testMemberId.isEmpty()
      ? List.of() : memberAdminLookupService.findActiveMemberIds(List.of(testMemberId));
    if (activeMemberIds.isEmpty()) {
      return AdminPushSendResponse.rejected(AdminPushOutcome.TEST_MEMBER_INVALID);
    }
    return sendAndRecord(request, route.get(), activeMemberIds, AdminAuditAction.ADMIN_PUSH_TEST_SENT);
  }

  /// 지금(KST)이 보내기를 막는 시간인지
  public boolean isQuietHoursNow() {
    LocalTime now = LocalTime.now(clock);
    return !now.isBefore(QUIET_HOURS_START) || now.isBefore(QUIET_HOURS_END);
  }

  private AdminPushSendResponse sendAndRecord(AdminPushRequest request, AdminMessageRoute route,
    List<String> memberIds, AdminAuditAction action) {
    String title = request.title().strip();
    AdminMessageSendResult result = adminMessageService.send(title, request.body().strip(), route, memberIds);
    // 관리자 기록 (누가·언제는 기록 서비스가 채움)
    adminAuditService.record(action, result.messageId(), auditDetailOf(memberIds.size(), result, title));
    return AdminPushSendResponse.sent(memberIds.size(), result);
  }

  // 관리자 기록 한 줄: "대상 12명 · 기록 12명 · 기기 성공 9 실패 1 · 제목 {앞 40자}"
  private static String auditDetailOf(int recipientCount, AdminMessageSendResult result, String title) {
    String titlePreview = title.length() > AUDIT_TITLE_PREVIEW_LENGTH
      ? title.substring(0, AUDIT_TITLE_PREVIEW_LENGTH) + "…" : title;
    return "대상 " + recipientCount + "명 · 기록 " + result.recordedMemberCount() + "명 · 기기 성공 "
      + result.sentDeviceCount() + " 실패 " + result.failedDeviceCount() + " · 제목 " + titlePreview;
  }

  /// 내용 검사 (제목·본문 필수와 길이, 갈 화면) > 갈 화면. 틀리면 빈 값
  private static Optional<AdminMessageRoute> validMessageRouteOf(AdminPushRequest request) {
    if (!isTextWithin(request.title(), AdminMessage.TITLE_MAX_LENGTH)
      || !isTextWithin(request.body(), AdminMessage.BODY_MAX_LENGTH)) {
      return Optional.empty();
    }
    return AdminMessageRoute.fromWire(request.route());
  }

  private static boolean isTextWithin(String text, int maximumLength) {
    return text != null && !text.isBlank() && text.strip().length() <= maximumLength;
  }

  /// 인원 판정: 0명 거절, 상한 초과 거절, 그 외 빈 값
  private static Optional<AdminPushOutcome> recipientCountOutcomeOf(int recipientCount) {
    if (recipientCount == 0) {
      return Optional.of(AdminPushOutcome.NO_RECIPIENTS);
    }
    if (recipientCount > MAXIMUM_RECIPIENT_COUNT) {
      return Optional.of(AdminPushOutcome.TOO_MANY_RECIPIENTS);
    }
    return Optional.empty();
  }

  /// 받는 사람 계산 결과: 활성 회원 id 또는 거절 사유
  private record TargetResolution(List<String> memberIds, Optional<AdminPushOutcome> rejection) {

    static TargetResolution of(List<String> memberIds) {
      return new TargetResolution(memberIds, Optional.empty());
    }

    static TargetResolution rejected(AdminPushOutcome outcome) {
      return new TargetResolution(List.of(), Optional.of(outcome));
    }
  }

  /// 받는 사람: 고른 회원(활성만) 또는 조건(그날까지 가입 + AI 호출 N회 이상, 활성만)
  private TargetResolution resolveTargets(AdminPushRequest request) {
    if (TARGET_MODE_MEMBERS.equals(request.targetMode())) {
      return resolveChosenMembers(request.memberIds());
    }
    if (TARGET_MODE_CONDITION.equals(request.targetMode())) {
      return resolveCondition(request.joinedOnOrBefore(), request.minimumAiCallCount());
    }
    return TargetResolution.rejected(AdminPushOutcome.INVALID_TARGET);
  }

  private TargetResolution resolveChosenMembers(List<String> memberIds) {
    if (memberIds == null || memberIds.isEmpty()) {
      return TargetResolution.rejected(AdminPushOutcome.NO_RECIPIENTS);
    }
    // 조회 전에 상한 확인 (긴 목록으로 큰 in 쿼리를 만들지 않게)
    List<String> distinctMemberIds = memberIds.stream()
      .filter(memberId -> memberId != null && !memberId.isBlank())
      .map(String::strip)
      .distinct()
      .toList();
    if (distinctMemberIds.size() > MAXIMUM_RECIPIENT_COUNT) {
      return TargetResolution.rejected(AdminPushOutcome.TOO_MANY_RECIPIENTS);
    }
    return TargetResolution.of(memberAdminLookupService.findActiveMemberIds(distinctMemberIds));
  }

  private TargetResolution resolveCondition(String joinedOnOrBefore, Integer minimumAiCallCount) {
    Optional<LocalDate> joinedDate = parseDate(joinedOnOrBefore);
    if (joinedDate.isEmpty() || minimumAiCallCount == null || minimumAiCallCount < 0) {
      return TargetResolution.rejected(AdminPushOutcome.INVALID_TARGET);
    }
    // 그날 포함: 다음 날 0시 전 가입
    LocalDateTime joinedBefore = joinedDate.get().plusDays(1).atStartOfDay();
    List<String> joinedMemberIds = memberAdminLookupService.findActiveMemberIdsJoinedBefore(joinedBefore);
    if (minimumAiCallCount == 0) {
      return TargetResolution.of(joinedMemberIds);
    }
    Set<String> aiUserIds = aiCallLogQueryService.findMemberIdsWithCallCountAtLeast(minimumAiCallCount);
    return TargetResolution.of(joinedMemberIds.stream().filter(aiUserIds::contains).toList());
  }

  private static Optional<LocalDate> parseDate(String text) {
    if (text == null || text.isBlank()) {
      return Optional.empty();
    }
    try {
      return Optional.of(LocalDate.parse(text.strip()));
    } catch (DateTimeParseException exception) {
      return Optional.empty();
    }
  }
}
