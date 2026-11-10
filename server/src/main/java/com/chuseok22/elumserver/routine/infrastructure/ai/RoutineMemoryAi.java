package com.chuseok22.elumserver.routine.infrastructure.ai;

import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.routine.core.RoutineMemoryFinding;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * AI 메모리 수정 찾기 호출: 입력 JSON 조립 > 설정된 텍스트 제공자 사슬 > matched·found 파싱
 * 입력은 카드 글·규칙 글뿐 (보호자 입력 원문·이름·일과 제목 없음 — 이름은 부르는 쪽이 자리표시로 바꿔 넘김)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineMemoryAi {

  private static final ObjectMapper OBJECT_MAPPER = DefaultJsonMapper.SHARED;

  private final TextClientRouter textClientRouter;

  /**
   * 수정 찾기 요청 입력
   *
   * @param firstCards    AI 가 처음 만든 카드 ("제목 / 설명")
   * @param confirmedCards 보호자가 확정한 카드
   * @param existingRules 이 보호자의 기존 규칙 (직접 적은 규칙 제외)
   * @param rejectedRules 보호자가 지운 규칙 (다시 가져오지 않게)
   */
  public record ExtractionInput(
    String task, List<String> firstCards, List<String> confirmedCards, List<ExistingRule> existingRules,
    List<RejectedRule> rejectedRules
  ) {

    public static ExtractionInput of(
      List<String> firstCards, List<String> confirmedCards, List<ExistingRule> existingRules,
      List<RejectedRule> rejectedRules
    ) {
      return new ExtractionInput("FIND_CARD_EDITS", firstCards, confirmedCards, existingRules, rejectedRules);
    }
  }

  public record ExistingRule(String id, RoutineMemoryRuleType type, String before, String after, String summary) {

  }

  public record RejectedRule(RoutineMemoryRuleType type, String before, String after) {

  }

  /// AI 가 돌려준 것 (검증 전): 짝지은 기존 규칙 id 와 새로 찾은 수정
  public record ExtractionResult(List<String> matchedRuleIds, List<RoutineMemoryFinding> foundFindings) {

  }

  /// 호출·파싱 실패는 던짐 — 부르는 쪽이 이 일과만 건너뜀 (알 수 없는 type 한 건은 그 건만 버림)
  public ExtractionResult extract(ExtractionInput input) {
    String json = textClientRouter.current().buildRoutineMemoryJson(toJson(input));
    try {
      JsonNode root = OBJECT_MAPPER.readTree(json);
      if (!root.path("matched").isArray() || !root.path("found").isArray()) {
        throw new IllegalStateException("메모리 응답에 matched·found 배열이 없음");
      }
      return new ExtractionResult(parseMatched(root.path("matched")), parseFound(root.path("found")));
    } catch (JsonProcessingException e) {
      log.warn("[routine memory] unreadable ai response : responseLength={}", LogTextLength.of(json));
      throw new IllegalStateException("메모리 응답을 읽지 못함", e);
    }
  }

  private static List<String> parseMatched(JsonNode matched) {
    List<String> ids = new ArrayList<>();
    matched.forEach(node -> {
      if (node.isTextual() && !node.asText().isBlank()) {
        ids.add(node.asText().trim());
      }
    });
    return ids;
  }

  private static List<RoutineMemoryFinding> parseFound(JsonNode found) {
    List<RoutineMemoryFinding> findings = new ArrayList<>();
    for (JsonNode node : found) {
      RoutineMemoryRuleType type = parseType(node.path("type").asText(""));
      if (type == null) {
        log.info("[routine memory] found dropped : reason=unknown type");
        continue;
      }
      findings.add(new RoutineMemoryFinding(type, textOrNull(node.path("before")), textOrNull(node.path("after")),
        textOrNull(node.path("summary"))));
    }
    return findings;
  }

  private static RoutineMemoryRuleType parseType(String text) {
    try {
      return RoutineMemoryRuleType.valueOf(text.trim().toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException e) {
      return null;
    }
  }

  private static String textOrNull(JsonNode node) {
    return node.isTextual() && !node.asText().isBlank() ? node.asText().trim() : null;
  }

  /// 시험 하네스·로그 길이 확인용으로 공개 (실제 호출과 같은 조립)
  public static String toJson(ExtractionInput input) {
    try {
      return OBJECT_MAPPER.writeValueAsString(input);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("메모리 요청 JSON 직렬화 실패", e);
    }
  }
}
