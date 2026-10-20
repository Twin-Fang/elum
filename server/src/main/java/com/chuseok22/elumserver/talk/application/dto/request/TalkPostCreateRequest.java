package com.chuseok22.elumserver.talk.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/// 검증 어노테이션을 쓰지 않는다. 필수값·길이·분류 검사는 TalkPostService 가 CustomException 으로 던진다.
@Schema(description = "이야기 올리기 요청")
public record TalkPostCreateRequest(
  @Schema(description = "나눌 일과 id. 필수. 오늘 일과(복사본) id 도 받으며 원본으로 바꿔 쓴다")
  String routineId,
  @Schema(description = "한마디. 선택, 최대 300자(코드포인트). 비면 없는 것으로 본다", example = "이렇게 하니 잘 따라 했어요")
  String note,
  @Schema(description = "분류. 필수. SELF_CARE, DAILY_FLOW, HOUSEHOLD, COMMUNITY, LEARNING, FEELINGS 중 하나",
    example = "DAILY_FLOW")
  String category,
  @Schema(description = "흐리게 보여줄 사진 카드 id 목록. 선택. 사진이 아닌 카드 id 는 무시한다")
  List<String> blurredStepIds
) {

}
