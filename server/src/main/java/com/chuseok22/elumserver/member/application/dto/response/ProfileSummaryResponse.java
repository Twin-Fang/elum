package com.chuseok22.elumserver.member.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "연결된 이룸이 하나. 여러 이룸이를 돌보는 보호자가 이룸이를 고를 때 쓴다")
public record ProfileSummaryResponse(

  @Schema(description = "이룸이 ID — X-Profile-Id 헤더에 넣는 값")
  String id,

  @Schema(description = "이룸이 호칭, 미설정 시 null", example = "하늘이")
  String nickname,

  @Schema(description = "캐릭터, 미설정 시 null", example = "LULU")
  CharacterType character
) {

  public static ProfileSummaryResponse from(Profile profile) {
    return new ProfileSummaryResponse(profile.getId(), profile.getNickname(), profile.getCharacter());
  }
}
