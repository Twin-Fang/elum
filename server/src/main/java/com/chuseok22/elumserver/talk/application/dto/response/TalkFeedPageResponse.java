package com.chuseok22.elumserver.talk.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "이야기 피드 한 쪽")
public record TalkFeedPageResponse(
  @Schema(description = "글 요약 목록(최신순)")
  List<TalkPostSummaryResponse> items,
  @Schema(description = "다음 쪽을 받을 cursor. 더 없으면 null")
  String nextCursor
) {

}
