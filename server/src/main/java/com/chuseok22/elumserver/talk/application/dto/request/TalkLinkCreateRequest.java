package com.chuseok22.elumserver.talk.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/// 검증 어노테이션을 쓰지 않는다. 필수값 검사는 TalkLinkService 가 CustomException 으로 던진다.
@Schema(description = "일과를 링크로 보내기 요청")
public record TalkLinkCreateRequest(
  @Schema(description = "보낼 일과 id. 필수. 내가 만든 일과여야 하며, 오늘 일과(복사본) id 도 받아 원본으로 바꿔 쓴다")
  String routineId,
  @Schema(description = "흐리게 보여줄 사진 카드 id 목록. 선택. 사진이 아닌 카드 id 는 무시한다. 이미 켜진 링크가 있으면 쓰지 않는다")
  List<String> blurredStepIds
) {

}
