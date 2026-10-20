package com.chuseok22.elumserver.talk.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

/// 검증 어노테이션을 쓰지 않는다. 둘 다 비었는지·길이·분류 검사는 TalkPostService 가 CustomException 으로 던진다.
@Schema(description = "이야기 고치기 요청. 보낸 항목만 바꾸며 둘 다 비우면 400")
public record TalkPostUpdateRequest(
  @Schema(description = "한마디. 안 보내면(null) 그대로 두고, 빈 문자열이면 지운다. 최대 300자(코드포인트)",
    example = "이렇게 하니 잘 따라 했어요")
  String note,
  @Schema(description = "분류. 안 보내면(null) 그대로 둔다. SELF_CARE, DAILY_FLOW, HOUSEHOLD, COMMUNITY, LEARNING, FEELINGS 중 하나",
    example = "DAILY_FLOW")
  String category
) {

}
