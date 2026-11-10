package com.chuseok22.elumserver.routine.core;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * AI 가 찾아 온 수정 한 건 검증 (순수 계산): 종류 > 글자 수 > 금지어·기관 이름·이름 자리표시 > 실제 카드 글과 맞는지
 * AI 말은 믿지 않고 처음 카드·확정 카드 글로만 확인 (낱말은 카드에 그대로 있어야 함, 카드 수 변화와 종류가 맞아야 함)
 */
public final class RoutineMemoryFindingValidator {

  /// before·after·요약 최대 글자 수
  public static final int MAX_TEXT_LENGTH = 60;
  /// before·after 최소 글자 수 (한 글자 낱말은 우연히 맞기 쉬움)
  static final int MIN_TEXT_LENGTH = 2;
  /// 나누기·합치기 카드 목록 구분자: 중점·빗금·쉼표
  private static final String PART_DELIMITER_PATTERN = "[·/,]";
  private static final int MIN_PART_COUNT = 2;

  private RoutineMemoryFindingValidator() {
  }

  /// 종류별로 안 쓰는 칸을 비우고 공백을 정리 (ADD 는 before 없음, REMOVE 는 after 없음)
  public static RoutineMemoryFinding normalize(RoutineMemoryFinding raw) {
    RoutineMemoryRuleType type = raw.type();
    String before = type == RoutineMemoryRuleType.ADD ? null : blankToNull(raw.before());
    String after = type == RoutineMemoryRuleType.REMOVE ? null : blankToNull(raw.after());
    return new RoutineMemoryFinding(type, before, after, blankToNull(raw.summary()));
  }

  /// 버려야 하면 로그용 짧은 영문 사유, 통과면 null (원문은 담지 않음)
  public static String rejectionReason(
    RoutineMemoryFinding finding, List<RoutineCardText> firstCards, List<RoutineCardText> confirmedCards,
    List<String> namePlaceholders
  ) {
    if (finding.type() == null || finding.type() == RoutineMemoryRuleType.MANUAL) {
      return "type";
    }
    if (!hasRequiredTexts(finding)) {
      return "missing text";
    }
    for (String text : new String[] {finding.before(), finding.after()}) {
      if (text == null) {
        continue;
      }
      if (text.length() > MAX_TEXT_LENGTH || text.length() < MIN_TEXT_LENGTH) {
        return "text length";
      }
      if (RoutineMemorySafetyFilter.rejectionReason(text) != null
        || RoutineMemorySafetyFilter.hasForbiddenTermOrContact(text)) {
        return "forbidden";
      }
      if (namePlaceholders.stream().anyMatch(placeholder -> containsText(List.of(text.toLowerCase(Locale.ROOT)), placeholder))) {
        return "name";
      }
    }
    return isSupportedByCards(finding.type(), finding.before(), finding.after(), firstCards, confirmedCards)
      ? null
      : "not in cards";
  }

  /// 카드 글에 실제로 그 수정이 있었나 (규칙을 새로 만들 때와 기존 규칙에 짝지을 때 같은 기준)
  public static boolean isSupportedByCards(
    RoutineMemoryRuleType type, String before, String after, List<RoutineCardText> firstCards,
    List<RoutineCardText> confirmedCards
  ) {
    List<String> firstTexts = textsOf(firstCards);
    List<String> confirmedTexts = textsOf(confirmedCards);
    int firstCount = firstCards.size();
    int confirmedCount = confirmedCards.size();
    return switch (type) {
      case WORD -> containsText(firstTexts, before) && !containsText(confirmedTexts, before)
        && containsText(confirmedTexts, after) && !containsText(firstTexts, after);
      case SPLIT -> confirmedCount > firstCount && containsText(firstTexts, before)
        && isNewPartsOf(after, confirmedTexts, firstTexts);
      case MERGE -> confirmedCount < firstCount && containsText(confirmedTexts, after)
        && isAllPartsIn(before, firstTexts);
      case ADD -> confirmedCount > firstCount && containsText(confirmedTexts, after)
        && !containsText(firstTexts, after);
      case REMOVE -> confirmedCount < firstCount && containsText(firstTexts, before)
        && !containsText(confirmedTexts, before);
      case MANUAL -> false;
    };
  }

  /// 규칙 한 줄 요약: WORD 는 서버가 "before 대신 after", 그 밖은 AI 요약이 쓸 만하면 그것(낱말을 담고 필터 통과, 60자 안), 아니면 서버 문형
  public static String summaryOf(RoutineMemoryFinding finding) {
    String before = finding.before();
    String after = finding.after();
    if (finding.type() == RoutineMemoryRuleType.WORD) {
      return before + " 대신 " + after;
    }
    String aiSummary = finding.summary();
    String loweredSummary = aiSummary == null ? "" : aiSummary.toLowerCase(Locale.ROOT);
    boolean isUsableAiSummary = aiSummary != null && aiSummary.length() <= MAX_TEXT_LENGTH
      && RoutineMemorySafetyFilter.isAllowed(aiSummary)
      && (containsText(List.of(loweredSummary), before) || containsText(List.of(loweredSummary), after));
    if (isUsableAiSummary) {
      return aiSummary;
    }
    return switch (finding.type()) {
      case SPLIT -> "'" + before + "' 카드는 '" + after + "' 카드로 나눠요";
      case MERGE -> "'" + before + "' 카드는 '" + after + "' 카드 하나로 합쳐요";
      case ADD -> "'" + after + "' 카드를 넣어요";
      case REMOVE -> "'" + before + "' 카드는 빼요";
      default -> before + " 대신 " + after;
    };
  }

  private static boolean hasRequiredTexts(RoutineMemoryFinding finding) {
    return switch (finding.type()) {
      case WORD, SPLIT, MERGE -> finding.before() != null && finding.after() != null
        && !finding.before().equalsIgnoreCase(finding.after());
      case ADD -> finding.after() != null;
      case REMOVE -> finding.before() != null;
      case MANUAL -> false;
    };
  }

  /// 나눈 카드 목록: 모두 확정 카드에 있고, 2개 이상이며, 하나라도 처음 카드에 없던 새 카드
  private static boolean isNewPartsOf(String after, List<String> confirmedTexts, List<String> firstTexts) {
    List<String> parts = partsOf(after);
    return parts.size() >= MIN_PART_COUNT
      && parts.stream().allMatch(part -> containsText(confirmedTexts, part))
      && parts.stream().anyMatch(part -> !containsText(firstTexts, part));
  }

  private static boolean isAllPartsIn(String before, List<String> firstTexts) {
    List<String> parts = partsOf(before);
    return parts.size() >= MIN_PART_COUNT && parts.stream().allMatch(part -> containsText(firstTexts, part));
  }

  private static List<String> partsOf(String text) {
    List<String> parts = new ArrayList<>();
    for (String part : text.split(PART_DELIMITER_PATTERN)) {
      if (!part.isBlank()) {
        parts.add(part.trim());
      }
    }
    return parts;
  }

  /// 카드마다 제목·설명 각각 (소문자). 낱말은 그 안에 부분 문자열로 있으면 "있다"
  private static List<String> textsOf(List<RoutineCardText> cards) {
    List<String> texts = new ArrayList<>();
    for (RoutineCardText card : cards) {
      for (String text : new String[] {card.title(), card.description()}) {
        if (text != null && !text.isBlank()) {
          texts.add(text.trim().toLowerCase(Locale.ROOT));
        }
      }
    }
    return texts;
  }

  private static boolean containsText(List<String> loweredTexts, String word) {
    if (word == null || word.isBlank()) {
      return false;
    }
    String lowered = word.trim().toLowerCase(Locale.ROOT);
    return loweredTexts.stream().anyMatch(text -> text.contains(lowered));
  }

  private static String blankToNull(String text) {
    return text == null || text.isBlank() ? null : text.trim();
  }
}
