package com.chuseok22.elumserver.member.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "초대 코드 넣기 — 이룸이에 합류")
public record RedeemProfileInviteRequest(

  @Schema(description = "함께하는 보호자에게 받은 여섯 글자. 소문자로 보내도 되고 사이 공백·하이픈이 있어도 된다",
    example = "A7K3M9")
  String code,

  @Schema(description = "이 이룸이 안에서 불릴 이름(선택, 최대 20자) — \"엄마\", \"센터 선생님\". 비우면 앱이 \"보호자\"로 부른다. "
    + "실명을 적을 필요는 없다", example = "아빠", nullable = true)
  String displayName
) {

}
