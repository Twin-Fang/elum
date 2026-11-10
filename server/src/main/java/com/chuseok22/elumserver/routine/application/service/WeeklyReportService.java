package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportWeeksResponse;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDate;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 주간 리포트 조회 (#1074): 이룸이 확인 > 요금제 확인(Free 는 첫 주 미리 보기만) > 주 정하기 > 그 주 집계 > 정리 글 붙이기
 * 보호자 전용 (이룸이 기기는 MANAGE 에서 막힘), 읽기만. 트랜잭션을 두지 않음 (읽기는 WeeklyReportReader, AI 는 정리 글 서비스)
 */
@Service
@RequiredArgsConstructor
public class WeeklyReportService {

  private final WeeklyReportReader weeklyReportReader;
  private final WeeklyReportSummaryService weeklyReportSummaryService;
  private final ProfileAccessGuard profileAccessGuard;
  private final EntitlementService entitlementService;
  private final SystemConfigService systemConfigService;

  /// requestedWeekStart: 그 주 아무 날 (null 이면 이번 주). 오늘이 든 주보다 뒤면 400
  public WeeklyReportResponse getWeeklyReport(Caller caller, LocalDate requestedWeekStart) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    String profileId = profile.getId();
    boolean hasWeeklyReportEntitlement = entitlementService.isAllowed(caller.memberId(), Entitlement.WEEKLY_REPORT);
    if (!hasWeeklyReportEntitlement && !isFirstWeekPreviewEnabled()) {
      // 요금제 확인: WEEKLY_REPORT 꺼짐 > 403 WEEKLY_REPORT_NOT_ALLOWED (이룸이 기기의 계정은 연결해 준 보호자)
      entitlementService.requireAllowed(caller.memberId(), Entitlement.WEEKLY_REPORT);
    }

    LocalDate today = LocalDate.now();
    ReportWeek week = resolveWeek(requestedWeekStart, today);
    if (!hasWeeklyReportEntitlement) {
      requireFirstWeekPreview(profileId, week);
    }

    WeeklyReportResponse report = weeklyReportReader.aggregate(profileId, week, today);
    WeeklyReportResponse.Summary summary = weeklyReportSummaryService.summaryFor(
      profileId, profile.getNickname(), caller.memberId(), week, report, CurrentLocale.get(), today);
    return report.withSummary(summary);
  }

  /// 마친 일과가 있는 주 목록 + Free 미리 보기 주. 권한과 무관하게 보호자면 볼 수 있음 (리포트 본문만 잠김)
  public WeeklyReportWeeksResponse getRecordedWeeks(Caller caller) {
    String profileId = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE).getId();
    LocalDate freePreviewWeekStart = null;
    boolean shouldOfferPreview = isFirstWeekPreviewEnabled()
      && !entitlementService.isAllowed(caller.memberId(), Entitlement.WEEKLY_REPORT);
    if (shouldOfferPreview) {
      freePreviewWeekStart = weeklyReportReader.findEarliestRecordedWeekStart(profileId).orElse(null);
    }
    return new WeeklyReportWeeksResponse(weeklyReportReader.listRecordedWeeks(profileId), freePreviewWeekStart);
  }

  private boolean isFirstWeekPreviewEnabled() {
    return systemConfigService.getBoolean(ConfigKey.FREE_WEEKLY_REPORT_FIRST_WEEK_PREVIEW);
  }

  /// 권한 없는 회원: 마친 일과가 있는 가장 이른 주만 허용, 그 밖은 403 WEEKLY_REPORT_NOT_ALLOWED
  private void requireFirstWeekPreview(String profileId, ReportWeek week) {
    Optional<LocalDate> previewWeekStart = weeklyReportReader.findEarliestRecordedWeekStart(profileId);
    boolean isPreviewWeek = previewWeekStart.isPresent() && previewWeekStart.get().equals(week.start());
    if (!isPreviewWeek) {
      throw new CustomException(Entitlement.WEEKLY_REPORT.rejectionCode());
    }
  }

  /// 요청 날짜 > 그 날이 든 주. 없으면 이번 주, 이번 주보다 뒤면 INVALID_INPUT_VALUE
  private static ReportWeek resolveWeek(LocalDate requestedWeekStart, LocalDate today) {
    ReportWeek currentWeek = ReportWeek.containing(today);
    if (requestedWeekStart == null) {
      return currentWeek;
    }
    ReportWeek requestedWeek = ReportWeek.containing(requestedWeekStart);
    if (requestedWeek.isAfter(currentWeek)) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return requestedWeek;
  }
}
