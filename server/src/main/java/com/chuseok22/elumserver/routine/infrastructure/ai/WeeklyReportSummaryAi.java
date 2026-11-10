package com.chuseok22.elumserver.routine.infrastructure.ai;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 주간 리포트 정리 글 AI 호출: 집계 입력 JSON 조립 > 설정된 텍스트 제공자 사슬 > lines 파싱
 * 입력은 일과 제목·카드 제목·횟수만 (이름은 {userName} 고정, 보호자 입력 원문·사진·회원 식별값 없음)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class WeeklyReportSummaryAi {

  private static final ObjectMapper OBJECT_MAPPER = DefaultJsonMapper.SHARED;
  /// AI 에 보내는 이름 자리표시 (응답에 그대로 돌아옴, 서버가 이름으로 바꿈)
  public static final String USER_NAME_TOKEN = "{userName}";
  /// 입력에 싣는 일과·남은 카드 최대 개수 (입력 토큰 제한)
  private static final int MAX_INPUT_ROUTINES = 8;
  private static final int MAX_TITLE_LENGTH = 40;

  private final TextClientRouter textClientRouter;

  /**
   * 정리 글 요청 입력
   *
   * @param userName 항상 {userName} (이름 자리표시)
   */
  public record SummaryInput(
    String task, String userName, int sentRoutineCount, int completedRoutineCount, int completionPercent,
    int starsEarned, int rewardReachedCount, int longestCompletedDayStreak,
    List<RoutineLine> routines, List<RemainingLine> remainingSteps
  ) {

  }

  public record RoutineLine(String title, int sentCount, int completedCount) {

  }

  public record RemainingLine(String routineTitle, String stepTitle, int remainingCount) {

  }

  /// 집계 > 입력 (제목 속 실제 이름은 자리표시로 가리고 길이를 자름)
  public static SummaryInput inputOf(WeeklyReportResponse report, String nickname, AppLocale language) {
    List<RoutineLine> routines = report.routines().stream()
      .limit(MAX_INPUT_ROUTINES)
      .map(routine -> new RoutineLine(safeTitle(routine.title(), nickname, language),
        routine.sentCount(), routine.completedCount()))
      .toList();
    List<RemainingLine> remainingSteps = report.remainingSteps().stream()
      .map(step -> new RemainingLine(safeTitle(step.routineTitle(), nickname, language),
        safeTitle(step.stepTitle(), nickname, language), step.remainingCount()))
      .toList();
    return new SummaryInput("WRITE_WEEKLY_REPORT_SUMMARY", USER_NAME_TOKEN, report.sentRoutineCount(),
      report.completedRoutineCount(), report.completionPercent(), report.starsEarned(), report.rewardReachedCount(),
      report.longestCompletedDayStreak(), routines, remainingSteps);
  }

  /// 새 정리 글 줄 (검증 전). 호출·파싱 실패는 던짐 — 부르는 쪽이 고정 문장으로 대신함
  public List<String> requestLines(SummaryInput input) {
    String json = textClientRouter.current().buildWeeklyReportSummaryJson(toJson(input));
    try {
      JsonNode lines = OBJECT_MAPPER.readTree(json).path("lines");
      if (!lines.isArray()) {
        throw new IllegalStateException("weekly report response has no lines array");
      }
      List<String> parsed = new ArrayList<>();
      lines.forEach(line -> {
        if (line.isTextual() && !line.asText().isBlank()) {
          parsed.add(line.asText().trim());
        }
      });
      return parsed;
    } catch (JsonProcessingException e) {
      log.warn("[weekly report] unreadable ai response : responseLength={}", LogTextLength.of(json));
      throw new IllegalStateException("weekly report response is not json", e);
    }
  }

  /// 입력 JSON (실제 호출과 같은 조립, 숫자 검증의 허용 값도 이 JSON 에서 뽑음)
  public static String toJson(SummaryInput input) {
    try {
      return OBJECT_MAPPER.writeValueAsString(input);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("weekly report input serialization failed", e);
    }
  }

  private static String safeTitle(String title, String nickname, AppLocale language) {
    String masked = NicknamePlaceholder.mask(title == null ? "" : title.trim(), nickname, language);
    return masked.length() > MAX_TITLE_LENGTH ? masked.substring(0, MAX_TITLE_LENGTH) : masked;
  }
}
