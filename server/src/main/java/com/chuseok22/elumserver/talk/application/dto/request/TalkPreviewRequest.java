package com.chuseok22.elumserver.talk.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

/// 검증 어노테이션을 쓰지 않는다. 필수값 검사는 TalkPostService 가 CustomException 으로 던진다.
@Schema(description = "이야기 올리기 미리보기 요청")
public record TalkPreviewRequest(
  @Schema(description = "나눌 일과 id. 필수. 오늘 일과(복사본) id 도 받으며 원본으로 바꿔 쓴다")
  String routineId
) {

}
