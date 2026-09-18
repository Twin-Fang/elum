package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 보호자가 카드를 직접 한 장 추가할 때의 요청 (이슈 #199).
 *
 * <p>제약 애너테이션이 없으면 컨트롤러의 {@code @Valid}는 아무 일도 하지 않는다.
 * 실제로 그래서 잘못된 입력이 AI를 18.7초 태운 뒤 500으로 끝난 적이 있다 (이슈 #215).
 */
@Schema(description = "일과 카드 추가 요청")
public record RoutineStepCreateRequest(

  @NotBlank(message = "카드 제목은 비울 수 없습니다.")
  @Size(max = 100, message = "카드 제목은 100자를 넘을 수 없습니다.")
  @Schema(description = "카드 제목", example = "우산을 챙겨요", requiredMode = Schema.RequiredMode.REQUIRED)
  String title,

  // 설명은 이룸이 화면에서 TTS로 그대로 읽힌다. 너무 길면 듣다 지친다.
  @Size(max = 300, message = "카드 설명은 300자를 넘을 수 없습니다.")
  @Schema(description = "카드 설명 (이룸이 화면에서 소리로 읽어 준다)", example = "현관에서 우산을 챙겨요.")
  String description
) {

  /** 설명을 비워 보내도 화면이 깨지지 않게 빈 문자열로 맞춘다. */
  public String descriptionOrEmpty() {
    return description == null ? "" : description.trim();
  }
}
