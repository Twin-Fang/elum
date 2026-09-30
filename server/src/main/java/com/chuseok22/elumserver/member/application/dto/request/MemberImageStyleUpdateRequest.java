package com.chuseok22.elumserver.member.application.dto.request;

import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import io.swagger.v3.oas.annotations.media.Schema;

// request DTO 에는 검증 어노테이션을 달지 않는 저장소 규칙(server/CLAUDE.md)이라 null 검사는 서비스가 한다.
@Schema(description = "카드 그림 방식 설정 요청")
public record MemberImageStyleUpdateRequest(

  @Schema(description = "카드 그림 방식. CARTOON(만화) · REALISTIC(실사) · PHOTO_ONLY(직접 사진, AI 그림 생략). 필수",
    example = "REALISTIC")
  ImageStyle imageStyle
) {

}
