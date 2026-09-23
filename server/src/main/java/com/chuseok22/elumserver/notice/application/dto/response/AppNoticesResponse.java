package com.chuseok22.elumserver.notice.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "보호자 홈 공지 팝업에 넣을 공지들")
public record AppNoticesResponse(

  @Schema(description = "\"보지 않기\"를 체크하고 닫으면 숨길 일수. 7 이면 \"일주일간 보지 않기\"", example = "7")
  int hideDays,

  @Schema(description = "지금 게시 중인 공지. 슬라이드 순서대로 최대 5개. 숨김은 기기에 있으므로 서버는 거르지 않는다")
  List<AppNoticeResponse> notices
) {

}
