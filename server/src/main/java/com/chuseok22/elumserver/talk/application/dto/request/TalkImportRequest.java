package com.chuseok22.elumserver.talk.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

/// 검증 어노테이션을 쓰지 않는다. profileId 비어 있음·묶음 소속 검사는 서비스가 CustomException 으로 던진다.
@Schema(description = "이야기 일과를 일과관리로 가져오는 요청")
public record TalkImportRequest(
  @Schema(description = "가져올 이룸이 id. 내가 연결된 이룸이여야 한다", example = "3f2a9c0d-1b2e-4f60-8a7b-123456789abc")
  String profileId,
  @Schema(description = "넣을 일과관리 묶음 id. 안 보내면(null) 묶음 밖 맨 앞, 보내면 그 묶음의 맨 뒤. 이 이룸이의 묶음이어야 한다",
    nullable = true)
  String groupId
) {

}
