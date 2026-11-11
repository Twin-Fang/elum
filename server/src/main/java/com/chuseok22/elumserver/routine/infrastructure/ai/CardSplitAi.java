package com.chuseok22.elumserver.routine.infrastructure.ai;

import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 카드 나누기 AI 호출: 카드 한 장 입력 JSON 조립 > 설정된 텍스트 제공자 사슬 > status·cards 파싱
 * 입력은 카드 제목·설명뿐 (이름은 부르는 쪽이 자리표시로 바꿔 넘김, 일과 제목·다른 카드·메모·회원 식별값 없음)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CardSplitAi {

  private static final ObjectMapper OBJECT_MAPPER = DefaultJsonMapper.SHARED;
  private static final String TASK_SPLIT_CARD = "SPLIT_CARD";

  private final TextClientRouter textClientRouter;

  /// AI 가 돌려준 것 (검증 전): 상태 글자와 나눈 카드
  public record RawSuggestion(String status, List<RawCard> cards) {

  }

  public record RawCard(String title, String description) {

  }

  /// 호출·파싱 실패는 던짐 — 부르는 쪽이 CARD_SPLIT_FAILED 로 바꿈
  public RawSuggestion requestSuggestion(String maskedTitle, String maskedDescription) {
    String json = textClientRouter.current().buildCardSplitJson(toJson(maskedTitle, maskedDescription));
    try {
      JsonNode root = OBJECT_MAPPER.readTree(json);
      if (!root.path("cards").isArray()) {
        throw new IllegalStateException("card split response has no cards array");
      }
      return new RawSuggestion(root.path("status").asText(""), parseCards(root.path("cards")));
    } catch (JsonProcessingException e) {
      log.warn("[card split] unreadable ai response : responseLength={}", LogTextLength.of(json));
      throw new IllegalStateException("card split response is not json", e);
    }
  }

  private static List<RawCard> parseCards(JsonNode cards) {
    List<RawCard> parsed = new ArrayList<>();
    for (JsonNode card : cards) {
      parsed.add(new RawCard(card.path("title").asText(""), card.path("description").asText("")));
    }
    return parsed;
  }

  /// 입력 JSON (시험 하네스·로그 길이 확인용으로 공개, 실제 호출과 같은 조립)
  public static String toJson(String maskedTitle, String maskedDescription) {
    try {
      return OBJECT_MAPPER.writeValueAsString(Map.of(
        "task", TASK_SPLIT_CARD, "title", maskedTitle, "description", maskedDescription));
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("card split input serialization failed", e);
    }
  }
}
