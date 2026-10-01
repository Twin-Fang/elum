package com.chuseok22.elumserver.member.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "초대 코드로 합류한 결과")
public record ProfileJoinResponse(

  @Schema(description = "합류한 이룸이. id 를 X-Profile-Id 헤더에 넣어 쓴다")
  ProfileSummaryResponse profile,

  @Schema(description = "합류하면서 지운 빈 이룸이의 ID들. 가입할 때 자동으로 생긴 이룸이 중 이름도 일과도 없던 것이다. "
    + "앱이 이 id 를 들고 있었다면 버리고 `GET /api/member/me` 로 다시 읽는다. 지운 것이 없으면 빈 배열")
  List<String> removedProfileIds
) {

}
