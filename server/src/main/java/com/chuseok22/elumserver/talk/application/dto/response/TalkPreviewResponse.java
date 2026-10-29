package com.chuseok22.elumserver.talk.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "이야기 올리기 미리보기: 이름을 가린 뒤의 글과 사진 카드 여부")
public record TalkPreviewResponse(
  @Schema(description = "이름을 가린 일과 제목", example = "이룸이 버스 타기")
  String title,
  @Schema(description = "카드 목록(순서대로)")
  List<PreviewStep> steps,
  @Schema(description = "보호자가 올린 사진 카드가 하나라도 있는가. true 면 흐리게 선택 화면을 보여준다")
  boolean hasGuardianPhoto
) {

  @Schema(description = "미리보기 카드 1장")
  public record PreviewStep(
    @Schema(description = "원본 카드 id. 올리기의 blurredStepIds 에 쓴다")
    String stepId,
    @Schema(description = "카드 순서", example = "1")
    int stepOrder,
    @Schema(description = "이름을 가린 카드 제목. 없을 수 있음")
    String title,
    @Schema(description = "이름을 가린 카드 설명")
    String description,
    @Schema(description = "보호자가 올린 사진인가(흐리게 선택 대상)")
    boolean isGuardianPhoto
  ) {

  }
}
