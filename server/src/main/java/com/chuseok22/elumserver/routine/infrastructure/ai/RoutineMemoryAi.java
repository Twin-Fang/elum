package com.chuseok22.elumserver.routine.infrastructure.ai;

import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * AI 메모 갱신 호출 (#1082): 비교 입력 JSON 조립 > 설정된 텍스트 제공자 사슬 > lines 파싱
 * 입력은 카드 글·메모만 (보호자 입력 원문·이름 없음 — 이름은 부르는 쪽이 자리표시로 바꿔 넘김)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineMemoryAi {

  private static final ObjectMapper OBJECT_MAPPER = DefaultJsonMapper.SHARED;

  private final TextClientRouter textClientRouter;

  /**
   * 메모 갱신 요청 입력
   *
   * @param edits          일과별 처음 AI 카드 <-> 확정 카드 (최신순)
   * @param currentNotes   지금 AI 줄
   * @param guardianNotes  보호자가 쓴 줄 (돌려받지 않음, 겹침 방지용)
   * @param dismissedNotes 보호자가 지운 줄 (다시 만들지 않게)
   * @param maxLines       돌려받을 최대 줄 수 (10 - 보호자 줄 수)
   */
  public record MemoryInput(
    String task, List<RoutineEdit> edits, List<String> currentNotes, List<String> guardianNotes,
    List<String> dismissedNotes, int maxLines
  ) {

    public static MemoryInput of(
      List<RoutineEdit> edits, List<String> currentNotes, List<String> guardianNotes, List<String> dismissedNotes,
      int maxLines
    ) {
      return new MemoryInput("UPDATE_CARD_MEMORY", edits, currentNotes, guardianNotes, dismissedNotes, maxLines);
    }
  }

  /// 일과 하나의 처음 <-> 확정. 카드는 "제목 / 설명"
  public record RoutineEdit(String routineTitle, List<String> aiCards, List<String> confirmedCards, int photoCardCount) {

  }

  /// 새 AI 줄 목록 (거르기 전). 호출·파싱 실패는 던짐 — 부르는 쪽이 이번 갱신만 건너뜀
  public List<String> buildLines(MemoryInput input) {
    String userContent = toJson(input);
    String json = textClientRouter.current().buildRoutineMemoryJson(userContent);
    try {
      JsonNode lines = OBJECT_MAPPER.readTree(json).path("lines");
      if (!lines.isArray()) {
        throw new IllegalStateException("메모 응답에 lines 배열이 없음");
      }
      List<String> parsed = new ArrayList<>();
      lines.forEach(line -> {
        if (line.isTextual() && !line.asText().isBlank()) {
          parsed.add(line.asText().trim());
        }
      });
      return parsed;
    } catch (JsonProcessingException e) {
      log.warn("[routine memory] unreadable ai response : responseLength={}", LogTextLength.of(json));
      throw new IllegalStateException("메모 응답을 읽지 못함", e);
    }
  }

  /// 시험 하네스·로그 길이 확인용으로 공개 (실제 호출과 같은 조립)
  public static String toJson(MemoryInput input) {
    try {
      return OBJECT_MAPPER.writeValueAsString(input);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("메모 요청 JSON 직렬화 실패", e);
    }
  }
}
