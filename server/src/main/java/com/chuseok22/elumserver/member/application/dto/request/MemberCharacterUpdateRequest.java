package com.chuseok22.elumserver.member.application.dto.request;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "캐릭터 설정 요청")
public record MemberCharacterUpdateRequest(

  @Schema(description = "선택한 캐릭터", example = "LULU")
  CharacterType character
) {

}
