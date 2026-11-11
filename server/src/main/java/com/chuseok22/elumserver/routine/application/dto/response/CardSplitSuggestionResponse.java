package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "카드 나누기 안 (저장하지 않음)")
public record CardSplitSuggestionResponse(

  @Schema(description = "SUGGESTED: 나눈 안 있음 / ALREADY_SHORT: 이미 행동 하나라 나눌 것이 없음", example = "SUGGESTED")
  Status status,

  @Schema(description = "SUGGESTED 면 2~3장, ALREADY_SHORT 면 빈 목록")
  List<Card> cards
) {

  public enum Status {
    SUGGESTED,
    ALREADY_SHORT
  }

  @Schema(description = "나눈 카드 한 장")
  public record Card(
    @Schema(description = "카드 제목", example = "컵에 물 담기") String title,
    @Schema(description = "카드 설명", example = "컵에 물을 담아요.") String description
  ) {

  }

  public static CardSplitSuggestionResponse suggested(List<Card> cards) {
    return new CardSplitSuggestionResponse(Status.SUGGESTED, List.copyOf(cards));
  }

  public static CardSplitSuggestionResponse alreadyShort() {
    return new CardSplitSuggestionResponse(Status.ALREADY_SHORT, List.of());
  }
}
