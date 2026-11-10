package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "카드 나누기 적용 요청 — 안 받기에서 받은 카드(보호자가 고쳤을 수 있음) 2~3장")
public record CardSplitRequest(

  @Schema(description = "그 카드 자리에 순서대로 넣을 카드 2~3장")
  List<Card> cards
) {

  @Schema(description = "나눈 카드 한 장")
  public record Card(

    @Schema(description = "카드 제목 (비울 수 없음, 100자 이하)", example = "컵에 물 담기")
    String title,

    @Schema(description = "카드 설명 (300자 이하)", example = "컵에 물을 담아요.")
    String description
  ) {

  }
}
