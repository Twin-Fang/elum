package com.chuseok22.elumserver.talk.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "일과를 링크로 보내기 결과. 웹 링크는 {공유 기준 주소}/s/{postId}")
public record TalkLinkResponse(
  @Schema(description = "링크 글 id")
  String postId,
  @Schema(description = "이미 켜진 링크를 돌려줬는가 (true 면 이번 요청의 흐리게 선택은 쓰지 않았다)")
  boolean isReused
) {

}
