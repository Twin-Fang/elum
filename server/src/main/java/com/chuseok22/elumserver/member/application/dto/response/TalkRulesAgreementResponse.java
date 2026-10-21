package com.chuseok22.elumserver.member.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "이야기 이용 규칙 동의 여부")
public record TalkRulesAgreementResponse(
  @Schema(description = "이용 규칙에 동의했는가")
  boolean hasAgreed
) {

}
