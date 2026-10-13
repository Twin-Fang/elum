package com.chuseok22.elumserver.link.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "연결 암호 넣기 (이룸이 휴대폰)")
public record RedeemLinkRequest(

  @Schema(description = "보호자에게 받은 여섯 글자. 소문자로 보내도 되고 사이 공백이 있어도 된다",
    example = "A7K3M9")
  @NotBlank
  String code,

  @Schema(description = "이룸이 휴대폰의 기기 이름(모델명). 선택 — 옛 앱은 보내지 않는다. 앞뒤 공백은 잘리고 "
    + "제어 문자는 빼며, 40자를 넘으면 잘라 저장한다", example = "iPhone 16", nullable = true)
  String deviceName
) {

}
