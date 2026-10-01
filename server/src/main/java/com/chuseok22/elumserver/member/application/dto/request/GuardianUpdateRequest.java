package com.chuseok22.elumserver.member.application.dto.request;

import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "내가 이 이룸이에서 불리는 이름·표시 고치기. 보낸 항목만 바뀐다")
public record GuardianUpdateRequest(

  @Schema(description = "표시용 구분. GUARDIAN(가족 보호자) · CAREGIVER(센터 선생님 등). 권한 차이는 없다. 보내지 않으면 그대로",
    example = "CAREGIVER", nullable = true)
  GuardianKind kind,

  @Schema(description = "이 이룸이 안에서 불릴 이름(최대 20자). 보내지 않으면 그대로, 빈 문자열이면 이름을 지운다", example = "센터 선생님",
    nullable = true)
  String displayName
) {

}
