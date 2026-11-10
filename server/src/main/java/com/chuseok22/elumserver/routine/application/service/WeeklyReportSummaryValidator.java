package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.core.RoutineMemorySafetyFilter;
import com.chuseok22.elumserver.routine.infrastructure.ai.WeeklyReportSummaryAi;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * AI 정리 글 검증: 줄 수 1~3, 줄 길이, 금지 낱말(진단·권유·평가·원인), 자리표시 모양, 입력에 없는 숫자
 * 하나라도 걸리면 글 전체를 버리고 부르는 쪽이 고정 문장으로 대신함 (판정은 낱말·숫자 포함 여부뿐)
 */
final class WeeklyReportSummaryValidator {

  static final int MAX_LINES = 3;
  /// 한 줄 최대 글자 수
  static final int MAX_LINE_LENGTH = 120;

  private static final Pattern NUMBER_PATTERN = Pattern.compile("\\d+");

  /**
   * 권유·평가·원인·효과 낱말 (소문자 비교). 진단·장애·치료는 RoutineMemorySafetyFilter 가 막음
   * 일상어와 겹치는 짧은 낱말은 넣지 않음 — 일과 제목이 막힘
   */
  private static final List<String> FORBIDDEN_ADVICE_TERMS = List.of(
    // 한국어: 권유·부탁·의무
    "해야", "하세요", "보세요", "해 보", "해보", "주세요", "하면 좋", "해 주", "바랍니다", "권해", "추천", "필요해", "필요합",
    "시도해", "나눠", "늘려", "줄여", "하자", "합시다",
    // 한국어: 평가·걱정·효과·원인
    "잘했", "잘하고", "대단", "훌륭", "칭찬", "부족", "아쉬", "걱정", "발전", "향상", "나아", "개선", "효과", "때문", "덕분",
    "탓", "원인", "성장",
    // 영어: advice, judgement, effect, cause
    "should", "try ", "consider", "recommend", "suggest", "need to", "needs to", "must ", "you could", "let's",
    "great job", "well done", "good job", "excellent", "impressive", "unfortunately", "worry", "improve", "progress",
    "effect", "because", "due to", "thanks to", "therapy", "treatment", "diagnos", "disorder", "disabilit", "autis"
  );

  private WeeklyReportSummaryValidator() {
  }

  /// 검증 결과: 통과하면 lines, 걸리면 rejectionReason (로그용 짧은 영문, 원문 없음)
  record Result(List<String> lines, String rejectionReason) {

    boolean isAccepted() {
      return rejectionReason == null;
    }
  }

  /// allowedNumbers: 입력 JSON 에 나온 숫자 문자열 전부 (집계 숫자 + 제목 속 숫자)
  static Result validate(List<String> rawLines, Set<String> allowedNumbers) {
    if (rawLines == null || rawLines.isEmpty()) {
      return rejected("no lines");
    }
    List<String> lines = new ArrayList<>();
    for (String rawLine : rawLines) {
      if (rawLine != null && !rawLine.isBlank()) {
        lines.add(rawLine.trim());
      }
    }
    if (lines.isEmpty() || lines.size() > MAX_LINES) {
      return rejected("line count");
    }
    for (String line : lines) {
      String reason = rejectionReasonOf(line, allowedNumbers);
      if (reason != null) {
        return rejected(reason);
      }
    }
    return new Result(List.copyOf(lines), null);
  }

  /// 입력 JSON 문자열 > 숫자 토큰 집합 (허용 숫자)
  static Set<String> numbersIn(String inputJson) {
    Set<String> numbers = new HashSet<>();
    Matcher matcher = NUMBER_PATTERN.matcher(inputJson);
    while (matcher.find()) {
      numbers.add(matcher.group());
    }
    return numbers;
  }

  private static String rejectionReasonOf(String line, Set<String> allowedNumbers) {
    if (line.length() > MAX_LINE_LENGTH) {
      return "line too long";
    }
    // 자리표시 {userName} 만 허용 (그 밖의 중괄호는 AI 가 만든 틀)
    String withoutToken = line.replace(WeeklyReportSummaryAi.USER_NAME_TOKEN, "");
    if (withoutToken.contains("{") || withoutToken.contains("}")) {
      return "unknown placeholder";
    }
    if (RoutineMemorySafetyFilter.hasForbiddenTermOrContact(withoutToken)) {
      return "forbidden term";
    }
    String lowered = withoutToken.toLowerCase(Locale.ROOT) + " ";
    for (String term : FORBIDDEN_ADVICE_TERMS) {
      if (lowered.contains(term)) {
        return "advice or judgement term";
      }
    }
    Matcher numbers = NUMBER_PATTERN.matcher(withoutToken);
    while (numbers.find()) {
      if (!allowedNumbers.contains(numbers.group())) {
        return "number not in input";
      }
    }
    return null;
  }

  private static Result rejected(String reason) {
    return new Result(List.of(), reason);
  }
}
