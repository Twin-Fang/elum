package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.Summary;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.SummarySource;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.routine.infrastructure.ai.WeeklyReportSummaryAi;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/**
 * 주간 리포트 정리 글: 대상 판정 > 저장된 글 > (없으면) 스위치·비용 상한 확인 > AI > 검증 > 저장
 * 실패·거절·스위치 꺼짐은 집계로 만든 고정 문장 (저장하지 않음, 다음 조회에서 다시 시도). 트랜잭션을 두지 않음 (AI 호출 중 연결을 쥐지 않게)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class WeeklyReportSummaryService {

  private final WeeklyReportSummaryStore weeklyReportSummaryStore;
  private final WeeklyReportSummaryAi weeklyReportSummaryAi;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;
  private final SystemConfigService systemConfigService;

  /**
   * 정리 글: 끝난 주이고 마친 일과가 있을 때만, 아니면 null
   *
   * @param costMemberId AI 호출 기록에 달 보호자
   * @param locale       요청(또는 일과) 언어 > 글 언어 ko | en
   */
  public Summary summaryFor(
    String profileId, String nickname, String costMemberId, ReportWeek week, WeeklyReportResponse report,
    AppLocale locale, LocalDate today
  ) {
    if (!isSummaryTarget(week, report, today)) {
      return null;
    }
    AppLocale language = WeeklyReportSummaryTexts.summaryLanguageOf(locale);
    Optional<WeeklyReportSummaryStore.StoredSummary> stored =
      weeklyReportSummaryStore.find(profileId, week.start(), language.code());
    if (stored.isPresent()) {
      return toSummary(stored.get().lines(), stored.get().source(), report, nickname, language);
    }
    return generate(profileId, nickname, costMemberId, week, report, language);
  }

  /// 이룸이 삭제: 정리 글 전부 지움
  public void forgetProfile(String profileId) {
    int deletedCount = weeklyReportSummaryStore.deleteAllOfProfile(profileId);
    if (deletedCount > 0) {
      log.info("[weekly report] summaries forgotten : profileId={}, count={}", profileId, deletedCount);
    }
  }

  /// 끝난 주(다음 월요일 0시가 지남) + 마친 일과 1개 이상
  private static boolean isSummaryTarget(ReportWeek week, WeeklyReportResponse report, LocalDate today) {
    boolean isWeekEnded = !week.start().plusDays(ReportWeek.DAYS_PER_WEEK).isAfter(today);
    return isWeekEnded && report.completedRoutineCount() > 0;
  }

  private Summary generate(
    String profileId, String nickname, String costMemberId, ReportWeek week, WeeklyReportResponse report,
    AppLocale language
  ) {
    // 스위치 꺼짐·비용 상한 > AI 없이 고정 문장
    if (!systemConfigService.getBoolean(ConfigKey.WEEKLY_REPORT_AI_ENABLED)) {
      return fallbackSummary(report, nickname, language);
    }
    if (aiDailyBudgetGuard.isReached()) {
      log.info("[weekly report] ai skipped : daily budget reached, profileId={}", profileId);
      return fallbackSummary(report, nickname, language);
    }
    List<String> lines;
    try {
      lines = requestValidatedLines(profileId, nickname, costMemberId, report, language);
    } catch (RuntimeException e) {
      log.warn("[weekly report] ai failed, using fixed sentences : profileId={}", profileId, e);
      return fallbackSummary(report, nickname, language);
    }
    if (lines.isEmpty()) {
      return fallbackSummary(report, nickname, language);
    }
    return saveAndRespond(profileId, nickname, week, report, language, lines);
  }

  /// AI 호출 > 검증. 검증에서 걸리면 빈 목록 (사유는 로그)
  private List<String> requestValidatedLines(
    String profileId, String nickname, String costMemberId, WeeklyReportResponse report, AppLocale language
  ) {
    WeeklyReportSummaryAi.SummaryInput input = WeeklyReportSummaryAi.inputOf(report, nickname, language);
    String previousMemberId = AiCallContext.currentMemberId();
    AiCallContext.setMemberId(costMemberId);
    List<String> rawLines;
    try {
      rawLines = AiCallContext.callWithContentLocale(language, () -> weeklyReportSummaryAi.requestLines(input));
    } finally {
      AiCallContext.setMemberId(previousMemberId);
    }
    WeeklyReportSummaryValidator.Result validation = WeeklyReportSummaryValidator.validate(
      rawLines, WeeklyReportSummaryValidator.numbersIn(WeeklyReportSummaryAi.toJson(input)));
    if (!validation.isAccepted()) {
      log.warn("[weekly report] ai text rejected, using fixed sentences : profileId={}, reason={}",
        profileId, validation.rejectionReason());
      return List.of();
    }
    return validation.lines();
  }

  /// 저장 (동시에 먼저 저장됐으면 그 글을 씀, 저장 실패는 로그 후 이번 응답에만 실음)
  private Summary saveAndRespond(
    String profileId, String nickname, ReportWeek week, WeeklyReportResponse report, AppLocale language,
    List<String> lines
  ) {
    try {
      weeklyReportSummaryStore.save(profileId, week.start(), language.code(), lines, SummarySource.AI);
    } catch (DataIntegrityViolationException e) {
      Optional<WeeklyReportSummaryStore.StoredSummary> existing =
        weeklyReportSummaryStore.find(profileId, week.start(), language.code());
      if (existing.isPresent()) {
        return toSummary(existing.get().lines(), existing.get().source(), report, nickname, language);
      }
      log.warn("[weekly report] save conflict but no stored row : profileId={}", profileId, e);
    } catch (RuntimeException e) {
      log.warn("[weekly report] save failed, responding without saving : profileId={}", profileId, e);
    }
    return toSummary(lines, SummarySource.AI, report, nickname, language);
  }

  private Summary fallbackSummary(WeeklyReportResponse report, String nickname, AppLocale language) {
    return toSummary(WeeklyReportSummaryTexts.fallbackLines(report, language), SummarySource.FALLBACK, report,
      nickname, language);
  }

  /// 저장된 줄이 비었으면(읽기 실패) 고정 문장으로 대신함
  private Summary toSummary(
    List<String> lines, SummarySource source, WeeklyReportResponse report, String nickname, AppLocale language
  ) {
    if (lines.isEmpty()) {
      return fallbackSummary(report, nickname, language);
    }
    return new Summary(WeeklyReportSummaryTexts.withNickname(lines, nickname, language), source);
  }
}
