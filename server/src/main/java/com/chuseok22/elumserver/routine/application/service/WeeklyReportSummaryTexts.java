package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.WeeklyReportSummaryAi;
import java.util.ArrayList;
import java.util.List;

/**
 * 정리 글 문장 규칙: 요청 언어 > 글 언어(ko | en), 집계 > 고정 문장(FALLBACK), {userName} > 이룸이 이름
 * 고정 문장은 집계 숫자만 쓰고 일과·카드 제목은 넣지 않음
 */
final class WeeklyReportSummaryTexts {

  /// 이 길이 이상 이어진 날부터 연속 문장을 넣음
  private static final int MIN_STREAK_DAYS_TO_MENTION = 2;

  private WeeklyReportSummaryTexts() {
  }

  /// 요청 언어 > 글 언어: ko 는 한국어, 그 밖은 영어 (지시문·고정 문장이 ko·en 만 있음)
  static AppLocale summaryLanguageOf(AppLocale requestLocale) {
    return requestLocale == AppLocale.KO ? AppLocale.KO : AppLocale.EN;
  }

  /// 집계 > 고정 문장 1~3줄: 보낸·마친 일과, 받은 별(있으면), 이어서 마친 날(2일 이상이면)
  static List<String> fallbackLines(WeeklyReportResponse report, AppLocale language) {
    boolean isKorean = language == AppLocale.KO;
    String userName = WeeklyReportSummaryAi.USER_NAME_TOKEN;
    List<String> lines = new ArrayList<>();
    lines.add(isKorean
      ? "%s는 한 주 동안 일과 %d개 중 %d개를 마쳤어요.".formatted(userName, report.sentRoutineCount(), report.completedRoutineCount())
      : "%s completed %d of %d routines during the week.".formatted(userName, report.completedRoutineCount(), report.sentRoutineCount()));
    if (report.starsEarned() > 0) {
      lines.add(isKorean
        ? "받은 별은 %d개예요.".formatted(report.starsEarned())
        : "Stars earned: %d.".formatted(report.starsEarned()));
    }
    if (report.longestCompletedDayStreak() >= MIN_STREAK_DAYS_TO_MENTION) {
      lines.add(isKorean
        ? "일과를 마친 날이 %d일 이어졌어요.".formatted(report.longestCompletedDayStreak())
        : "Routines were completed on %d days in a row.".formatted(report.longestCompletedDayStreak()));
    }
    return lines;
  }

  /// 저장된 줄의 {userName} > 지금 이름 (ko 는 받침에 맞춰 조사를 다시 고름, 이름이 비면 호칭 그대로)
  static List<String> withNickname(List<String> lines, String nickname, AppLocale language) {
    String placeholder = NicknamePlaceholder.placeholderFor(language);
    return lines.stream()
      .map(line -> line.replace(WeeklyReportSummaryAi.USER_NAME_TOKEN, placeholder))
      .map(line -> NicknamePlaceholder.restore(line, nickname, language))
      .toList();
  }
}
