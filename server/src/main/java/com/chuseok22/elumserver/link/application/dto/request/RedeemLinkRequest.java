package com.chuseok22.elumserver.link.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "연결 암호 넣기 (이룸이 휴대폰)")
public record RedeemLinkRequest(

  @Schema(description = "보호자에게 받은 여섯 글자. 소문자로 보내도 되고 사이 공백이 있어도 된다",
    example = "A7K3M9")
  @NotBlank
  String code
) {

}
