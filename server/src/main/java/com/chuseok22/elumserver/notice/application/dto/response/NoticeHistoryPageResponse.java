package com.chuseok22.elumserver.notice.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "공지 탭 목록 한 쪽")
public record NoticeHistoryPageResponse(

  @Schema(description = "최근 올라온 순")
  List<NoticeHistoryItemResponse> items,

  @Schema(description = "다음 쪽을 부를 cursor(마지막 항목의 id). 마지막 쪽이면 null")
  String nextCursor
) {

}
