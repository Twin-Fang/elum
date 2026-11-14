package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.WeeklyReportSummaryAi;
import java.util.ArrayList;
import java.util.List;

/**
 * 정리 글 문장 규칙: 요청 언어 > 글 언어(다섯 언어), 집계 > 고정 문장(FALLBACK), {userName} > 이룸이 이름
 * 고정 문장은 집계 숫자만 쓰고 일과·카드 제목은 넣지 않음
 */
final class WeeklyReportSummaryTexts {

  /// 이 길이 이상 이어진 날부터 연속 문장을 넣음
  private static final int MIN_STREAK_DAYS_TO_MENTION = 2;

  private WeeklyReportSummaryTexts() {
  }

  /// 요청 언어 > 글 언어 (지시문·고정 문장이 다섯 언어 모두 있음)
  static AppLocale summaryLanguageOf(AppLocale requestLocale) {
    return requestLocale;
  }

  /// 집계 > 고정 문장 1~3줄: 보낸·마친 일과, 받은 별(있으면), 이어서 마친 날(2일 이상이면)
  static List<String> fallbackLines(WeeklyReportResponse report, AppLocale language) {
    String userName = WeeklyReportSummaryAi.USER_NAME_TOKEN;
    List<String> lines = new ArrayList<>();
    lines.add(weekLine(language).formatted(userName, report.sentRoutineCount(), report.completedRoutineCount()));
    if (report.starsEarned() > 0) {
      lines.add(starsLine(language).formatted(report.starsEarned()));
    }
    if (report.longestCompletedDayStreak() >= MIN_STREAK_DAYS_TO_MENTION) {
      lines.add(streakLine(language).formatted(report.longestCompletedDayStreak()));
    }
    return lines;
  }

  /// 한 주 문장 (자리: 이름, 보낸 일과 수, 마친 일과 수)
  private static String weekLine(AppLocale language) {
    return switch (language) {
      case KO -> "%1$s는 한 주 동안 일과 %2$d개 중 %3$d개를 마쳤어요.";
      case JA -> "%1$sは今週、日課%2$d個のうち%3$d個を終えました。";
      case ZH -> "%1$s这一周完成了%2$d个日常中的%3$d个。";
      case ES -> "%1$s completó %3$d de %2$d rutinas esta semana.";
      default -> "%1$s completed %3$d of %2$d routines during the week.";
    };
  }

  /// 받은 별 문장 (자리: 별 수)
  private static String starsLine(AppLocale language) {
    return switch (language) {
      case KO -> "받은 별은 %d개예요.";
      case JA -> "もらった星は%d個です。";
      case ZH -> "获得的星星有%d颗。";
      case ES -> "Estrellas ganadas: %d.";
      default -> "Stars earned: %d.";
    };
  }

  /// 이어서 마친 날 문장 (자리: 날 수)
  private static String streakLine(AppLocale language) {
    return switch (language) {
      case KO -> "일과를 마친 날이 %d일 이어졌어요.";
      case JA -> "日課を終えた日が%d日続きました。";
      case ZH -> "连续%d天完成了日常。";
      case ES -> "Completó rutinas %d días seguidos.";
      default -> "Routines were completed on %d days in a row.";
    };
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
