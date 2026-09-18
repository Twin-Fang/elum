package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

/**
 * 일과 카드 수정 요청 (순서 변경 포함 — 이슈 #199).
 *
 * <p><b>보낸 필드만 바뀐다.</b> 순서만 옮길 때 {@code stepOrder}만 보내면 제목·설명은
 * 그대로 남는다. 예전에는 넘어온 값을 그대로 덮어써서, 순서만 보내면 제목이 지워졌다.
 */
@Schema(description = "일과 카드 수정 요청 — 보낸 필드만 바뀐다")
public record RoutineStepUpdateRequest(

  @Size(max = 100, message = "카드 제목은 100자를 넘을 수 없습니다.")
  @Schema(description = "바꿀 카드 제목. 안 보내면 그대로 둔다", example = "옷을 입어요")
  String title,

  @Size(max = 300, message = "카드 설명은 300자를 넘을 수 없습니다.")
  @Schema(description = "바꿀 카드 설명. 안 보내면 그대로 둔다", example = "현관 우산꽂이에서 파란색 우산을 챙겨요.")
  String description,

  // 화면은 화살표로 한 칸씩 옮긴다 (#198 §7). 목표 자리를 그대로 보내면
  // 서버가 그 자리에 끼워 넣고 나머지를 1..N으로 다시 채운다.
  @Min(value = 1, message = "카드 순서는 1부터 시작합니다.")
  @Schema(description = "옮길 자리(1부터). 안 보내면 순서를 그대로 둔다", example = "2")
  Integer stepOrder
) {

}
