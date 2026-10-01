package com.chuseok22.elumserver.member.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "함께하는 사람 목록")
public record GuardianListResponse(

  @Schema(description = "이 이룸이를 함께 돌보는 사람들. 먼저 합류한 차례. 호출한 사람도 한 줄로 들어 있다(me=true)")
  List<GuardianResponse> guardians
) {

}
